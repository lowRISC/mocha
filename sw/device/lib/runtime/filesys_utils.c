// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "runtime/filesys_utils.h"
#include "builtin.h"
#include "runtime/bytedump.h"
#include "runtime/print.h"
#include "runtime/sdcard.h"
#include "runtime/string.h"

// 'Private' function declarations
static int block_ensure(fs_utils_state_t *fs, uint32_t block);
static bool end_of_chain(uint32_t cluster);
static bool cluster_next(fs_utils_state_t *fs, uint32_t *nextCluster, uint32_t cluster);
static bool object_seek(fs_utils_state_t *fs, fs_utils_obj_state_t *obj, uint32_t offset);
static size_t object_read(fs_utils_state_t *fs, fs_utils_obj_state_t *obj, uint8_t buf[],
                          size_t len);
static uint16_t as_lower_case(uint8_t ch);
static void generate_lfn(uint16_t *ucs, size_t ucs_max, const fs_utils_dir_entry_t *entry);
static bool include_entry(fs_utils_dir_entry_flags_t entryFlags, fs_utils_dir_flags_t flags);

// Ensure that the specified block is available in memory for access.
static int block_ensure(fs_utils_state_t *fs, uint32_t block)
{
    // Check whether this block is already available.
    unsigned int idx = 0;
    while (idx < FS_UTILS_CACHE_ENTRIES) {
        if (block == fs->blockCache[idx].block) {
            return (int)idx;
        }
        idx++;
    }
    idx = fs->blockCacheNext;
    if (fs->uart) {
        uprintf(fs->uart, " (reading blk 0x%x)\n", block);
    }
    if (read_blocks(fs->spi, block, fs->blockCache[idx].buf, 1u, fs->uart)) {
        fs->blockCache[idx].block = block;
        // Round-robin replacement of cached blocks.
        if (++fs->blockCacheNext >= FS_UTILS_CACHE_ENTRIES) {
            fs->blockCacheNext = 0u;
        }
        return (int)idx;
    }
    return -1;
}

// Is the specified cluster number an End of Chain marker?
// (a number of different values are used as EOC markers.)
static inline bool end_of_chain(uint32_t cluster)
{
    return (cluster <= 1u) || (cluster >= 0x0ffffff8u);
}

// Read the next cluster in the cluster chain of an object.
static bool cluster_next(fs_utils_state_t *fs, uint32_t *nextCluster, uint32_t cluster)
{
    // Byte offset of the corresponding entry within the FAT.
    uint32_t byteOffset = cluster << 2;
    // Determine the block number of the part of the FAT that describes this cluster.
    uint32_t block = fs->fatStart + (byteOffset >> FS_UTILS_BYTES_PER_BLOCK_SHIFT);
    int idx = block_ensure(fs, block);
    if (idx < 0) {
        // Failed to read the block from the medium.
        return false;
    }
    *nextCluster = read32le(&fs->blockCache[idx].buf[byteOffset & (FS_UTILS_BLOCK_LEN - 1u)]);
    // The upper nibble of the cluster must be ignored; reserved for future use.
    *nextCluster &= ~0xf0000000u;
    return true;
}

// Seek to the given offset within an object (file/directory).
bool object_seek(fs_utils_state_t *fs, fs_utils_obj_state_t *obj, uint32_t offset)
{
    // First validate the requested offset.
    if (offset > obj->length) {
        return false;
    }
    // Start either from the current file offset (trusted) or the beginning of the file.
    uint32_t currCluster = obj->currCluster;
    uint32_t currOffset = obj->offset & ~fs->clusterMask;
    if (offset < currOffset) {
        currCluster = obj->firstCluster;
        currOffset = 0u;
    }
    // Scan forwards through the cluster chain until we find the correct cluster.
    while (offset - currOffset >= fs->clusterBytes) {
        uint32_t nextCluster;
        if (!cluster_next(fs, &nextCluster, currCluster)) {
            // Leave the current position unchanged.
            return false;
        }
        currCluster = nextCluster;
        currOffset += fs->clusterBytes;
    }
    // Atomically update the current position with a consistent cluster number and offset.
    obj->currCluster = currCluster;
    obj->offset = offset;
    return true;
}

// Read a contiguous sequence of bytes from an object (file/directory).
static size_t object_read(fs_utils_state_t *fs, fs_utils_obj_state_t *obj, uint8_t buf[],
                          size_t len)
{
    if (fs->uart) {
        uprintf(fs->uart, "reading 0x%x byte(s) at offset 0x%x\n", (unsigned int)len, obj->offset);
    }

    size_t bytesRead = 0u;
    while (len > 0u && obj->offset < obj->length) {
        uint32_t currBlock = block_number(fs, obj->currCluster, obj->offset & fs->clusterMask);

        // Ensure that the block containing the current offset is available for use, if it
        // can be read from the medium.
        int idx = block_ensure(fs, currBlock);
        if (idx < 0) {
            return bytesRead;
        }
        // Locate this block within the block cache; its availability is guaranteed at this point.
        const uint8_t *dataBuf = fs->blockCache[idx].buf;

        // How much data do we have available at the current offset?
        size_t blockOffset = obj->offset & (FS_UTILS_BLOCK_LEN - 1u);
        size_t blockBytesLeft = FS_UTILS_BLOCK_LEN - blockOffset;
        size_t objBytesLeft = obj->length - obj->offset;
        size_t bytesAvail = (objBytesLeft > blockBytesLeft) ? blockBytesLeft : objBytesLeft;
        // Limit this request to the bytes immediately available.
        size_t chunk_len = (len > bytesAvail) ? bytesAvail : len;

        // Have we reached the end of this cluster but not the end of the object data?
        uint32_t next_offset = obj->offset + chunk_len;
        if (!(next_offset & fs->clusterMask) && obj->length > next_offset) {
            uint32_t nextCluster;
            if (!cluster_next(fs, &nextCluster, obj->currCluster)) {
                // Note: we're leaving the object state consistent here, despite the read failure.
                return bytesRead;
            }
            // Store the updated cluster number for the new offset.
            obj->currCluster = nextCluster;
        }
        // Advance the current offset, now that we know that the new offset is consistent wtih the
        // cluster number.
        obj->offset += chunk_len;

        // We have no memcpy implementation presently.
        (void)memcpy(buf, &dataBuf[blockOffset], chunk_len);
        buf += chunk_len;
        len -= chunk_len;
        bytesRead += chunk_len;
    }
    return bytesRead;
}

// public:
// Test for the presence of a FAT32 partition, read the partition properties
// and then locate the cluster heap and root directory.
bool fs_utils_init(fs_utils_state_t *fs, spi_host_t spi, uart_t uart)
{
    // Initialise all state information; no partition details, empty block cache,
    // no file/dir handles.
    fin(fs);

    // Store pointers to SPI Host for SD comms and (optional) UART for logging
    fs->spi = spi;
    fs->uart = uart;

    // Read the Master Boot Record (MBR) from block 0 at the very start of the medium.
    uint8_t *dataBuffer = fs->buf.dataBuffer;
    if (!read_blocks(fs->spi, 0, dataBuffer, 1u, fs->uart)) {
        if (fs->uart) {
            uprintf(fs->uart, "Unable to read the MBR of the SD card\n");
        }
        return false;
    }

    // We require MBR, as used by manufacturers for greatest compatibility, not GPT.
    if (dataBuffer[0x1fe] != 0x55 || dataBuffer[0x1ff] != 0xaa) {
        if (fs->uart) {
            uprintf(fs->uart, "Unable to parse the MBR of the SD card\n");
        }
        return false;
    }

    // The MBR describes up to four primary partitions.
    uint32_t blk_offset;
    bool use_lba = true;
    bool found = false;

    for (unsigned part = 0u; part < 1u; part++) {
        const unsigned partDesc = 0x1be + (part << 4);
        uint8_t part_type = dataBuffer[partDesc + 4];
        uint32_t lba_start = read32le(&dataBuffer[partDesc + 8]);
        uint32_t num_secs = read32le(&dataBuffer[partDesc + 12]);
        uint16_t start_c, end_c;
        uint8_t start_h, end_h;
        uint8_t start_s, end_s;
        read_chs(&start_c, &start_h, &start_s, &dataBuffer[partDesc + 1]);
        read_chs(&end_c, &end_h, &end_s, &dataBuffer[partDesc + 5]);
        if (fs->uart) {
            uprintf(fs->uart,
                    "Partition 0x%x : type 0x%x : start C 0x%x H 0x%x S 0x%x : end C 0x%x H 0x%x S "
                    "0x%x\n",
                    part, part_type, start_c, start_h, start_s, end_c, end_h, end_s);
            uprintf(fs->uart, "   LBA start: 0x%x sectors: 0x%x\n", lba_start, num_secs);
        }
        switch (part_type) {
        // Only FAT32 partitions (with or without LBA) are supported.
        case 0x0B:
            use_lba = false;
            // no break
        case 0x0C: {
            const uint16_t nheads = 255u;
            const uint16_t nsecs = 63u;
            if (use_lba) {
                blk_offset = lba_start;
            } else {
                blk_offset = chs_to_lba(start_c, start_h, start_s, nheads, nsecs);
            }
            if (fs->uart) {
                uprintf(fs->uart, "Expecting EBR at block 0x%x\n", blk_offset);
            }
            found = true;
        } break;
        default:
            if (fs->uart) {
                uprintf(fs->uart, "Not a suitable partition\n");
            }
            break;
        }
    }

    if (!found) {
        if (fs->uart) {
            uprintf(fs->uart, "Unable to locate a suitable partition\n");
        }
        return false;
    }

    // Read the EBR at the start of the partition.
    if (fs->uart) {
        uprintf(fs->uart, "Reading block 0x%x\n", blk_offset);
    }
    read_blocks(fs->spi, blk_offset, dataBuffer, 1u, fs->uart);
    if (fs->uart) {
        uart_dump_bytes(fs->uart, dataBuffer, FS_UTILS_BLOCK_LEN);
    }

    uint16_t bytesPerSector = read16le(&dataBuffer[0xb]);
    uint8_t secsPerCluster = dataBuffer[0xd];
    uint16_t resvdSectors = read16le(&dataBuffer[0xe]);
    uint8_t numFATs = dataBuffer[0x10];
    uint32_t secsPerFAT = read32le(&dataBuffer[0x24]);
    fs->rootCluster = read32le(&dataBuffer[0x2c]);

    if (fs->uart) {
        uprintf(fs->uart, "FAT32 0x%x FATs, secs per FAT 0x%x, bytes/sec 0x%x\n", numFATs,
                secsPerFAT, bytesPerSector);
        uprintf(fs->uart, " resvdSectors 0x%x\n", resvdSectors);
    }

    // Unfortunately FAT stores the literal values for bytes/sector and sectors/cluster but only
    // powers of two are permitted.
    fs->bytesPerSectorShift = ilog2(bytesPerSector);
    fs->secsPerClusterShift = ilog2(secsPerCluster);

    uint32_t fatOffset = resvdSectors;
    uint32_t clusterHeapOffset =
        ((resvdSectors + (numFATs * secsPerFAT)) << fs->bytesPerSectorShift) / FS_UTILS_BLOCK_LEN;

    // TODO: we do not fully cope with a difference between blocks and sectors at present.
    fs->blksPerClusterShift = fs->secsPerClusterShift;

    // Remember the volume-relative block numbers at which the (first) FAT, the cluster heap and
    // the root directory commence.
    fs->rootStart = ((fs->rootCluster - 2) << fs->secsPerClusterShift << fs->bytesPerSectorShift) /
                    FS_UTILS_BLOCK_LEN;
    fs->rootStart += blk_offset + clusterHeapOffset;
    fs->clusterHeapStart = blk_offset + clusterHeapOffset;
    fs->fatStart = blk_offset + fatOffset;

    if (fs->uart) {
        uprintf(fs->uart,
                "Cluster heap offset 0x%x Root cluster 0x%x log2(bytes/sec) 0x%x "
                "log2(secs/cluster) 0x%x\n",
                clusterHeapOffset, fs->rootCluster, fs->bytesPerSectorShift,
                fs->secsPerClusterShift);
    }

    // Sanity check the parameters, listing all objections.
    fs->partValid = true;
    if (fs->bytesPerSectorShift < 9 || fs->bytesPerSectorShift > 12) {
        if (fs->uart) {
            uprintf(fs->uart, " - bytes/sector is invalid\n");
        }
        fs->partValid = false;
    }
    if (fs->secsPerClusterShift > 25 - fs->bytesPerSectorShift) {
        if (fs->uart) {
            uprintf(fs->uart, " - sectors/cluster is invalid\n");
        }
        fs->partValid = false;
    }
    if (!fs->partValid) {
        if (fs->uart) {
            uprintf(fs->uart, "Unable to use this partition\n");
        }
        return false;
    }

    // Calculate derived properties.
    fs->clusterBytes = 1u << (fs->secsPerClusterShift + fs->bytesPerSectorShift);
    fs->clusterMask = fs->clusterBytes - 1u;

    // Record the fact that we have a valid partition.
    fs->partValid = true;
    // We should now have access to the root directory when required.
    return true;
}

// Finalise access to a filesystem.
void fin(fs_utils_state_t *fs)
{
    // Forget all files.
    for (unsigned idx = 0u; idx < FS_UTILS_MAX_FILES; idx++) {
        fs->files[idx].flags = 0u;
    }
    // Forget all directories.
    for (unsigned idx = 0u; idx < FS_UTILS_MAX_DIRS; idx++) {
        fs->dirs[idx].flags = 0u;
    }
    // Forget all cached blocks.
    for (unsigned idx = 0u; idx < FS_UTILS_CACHE_ENTRIES; idx++) {
        fs->blockCache[idx].block = FS_UTILS_INVALID_BLOCK;
    }
    fs->blockCacheNext = 0u;
    // Forget the medium itself.
    fs->partValid = false;
}

// Return the block number corresponding to the given byte offset within the specified cluster
// of the file system, or UINT32_MAX if invalid.
uint32_t block_number(fs_utils_state_t *fs, uint32_t cluster, uint32_t offset)
{
    offset >>= FS_UTILS_BYTES_PER_BLOCK_SHIFT;
    return fs->clusterHeapStart + ((cluster - 2u) << fs->blksPerClusterShift) + offset;
}

// Validate directory handle.
inline bool dh_valid(fs_utils_state_t *fs, fs_utils_dir_handle_t dh)
{
    return dh < FS_UTILS_MAX_DIRS && (fs->dirs[dh].flags & FS_UTILS_FLAG_VALID);
}

// Validate file handle.
inline bool fh_valid(fs_utils_state_t *fs, fs_utils_file_handle_t fh)
{
    return fh < FS_UTILS_MAX_FILES && (fs->files[fh].flags & FS_UTILS_FLAG_VALID);
}

// Get a handle to the root directory of the mounted partition.
fs_utils_dir_handle_t rootdir_open(fs_utils_state_t *fs)
{
    if (!fs->partValid) {
        return FS_UTILS_INVALID_DIR_HANDLE;
    }
    return dir_open(fs, fs->rootCluster);
}

// Open a directory object that started in the given cluster.
fs_utils_dir_handle_t dir_open(fs_utils_state_t *fs, uint32_t cluster)
{
    // Ensure that we have a directory handle available
    fs_utils_dir_handle_t dh = 0u;
    while (fs->dirs[dh].flags & FS_UTILS_FLAG_VALID) {
        if (++dh >= FS_UTILS_MAX_DIRS) {
            return FS_UTILS_INVALID_DIR_HANDLE;
        }
    }
    // Initialise directory fs.
    fs->dirs[dh].flags = FS_UTILS_FLAG_VALID;
    fs->dirs[dh].offset = 0u;
    fs->dirs[dh].length = ~0u; // A special directory entry marks its end.
    fs->dirs[dh].currCluster = cluster;
    fs->dirs[dh].firstCluster = cluster;
    return dh;
}

// Return the next object within a directory, including optionally the full name of the object
// (LFN support). If 'ucs' is null then the UCS-2 name is not returned.
//
// The returned characters are UCS-2 (not ASCII bytes) and a Long FileName may consist of up to
// 255 UCS-2 characters.
bool dir_next(fs_utils_state_t *fs, fs_utils_dir_handle_t dh, fs_utils_dir_entry_t *entry,
              fs_utils_dir_flags_t flags, uint16_t *ucs, size_t ucs_max)
{
    if (!dh_valid(fs, dh)) {
        return false;
    }

    uint8_t entryType;
    bool hasLFN = false;
    do {
        fs_utils_dir_entry_flags_t entryFlags = DirEntryFlag_Default;
        uint8_t dir_entry[0x20u];
        if (sizeof(dir_entry) != object_read(fs, &fs->dirs[dh], dir_entry, sizeof(dir_entry))) {
            return false;
        }
        if (fs->uart) {
            uprintf(fs->uart, "Dir entry:\n");
            uart_dump_bytes(fs->uart, dir_entry, sizeof(dir_entry));
        }
        entryType = dir_entry[0];

        uint8_t attribs = dir_entry[0xb];

        // Are we required to return this entry?
        // - _Raw demands absolutely no processing; _even_ the end of directory entry is returned.
        //
        // Ordinarily Deleted/Hidden files will be skipped, but the following flags override that
        // behaviour:
        // - _IncludeDeleted
        // - _IncludeHidden

        // Collect entry flags;
        if (hasLFN) {
            entryFlags |= DirEntryFlag_HasLongName;
        }
        if (attribs & 0x08) {
            entryFlags |= DirEntryFlag_VolumeLabel;
        }
        if (attribs & 0x010) {
            entryFlags |= DirEntryFlag_Subdirectory;
        }
        if (entryType == 0xe5) {
            entryFlags |= DirEntryFlag_Deleted;
        }

        bool entryWanted = true;
        if (!(flags & DirFlag_Raw)) {
            if (attribs == 0x0fu) {
                // Collect any Long FileName prefix entries.
                if (ucs) {
                    // The sequence number allows us to calculate the offset within the buffer.
                    uint8_t seqNumber = (entryType & 0x1fu);
                    if (seqNumber >= 0x01 && seqNumber <= 0x14u) {
                        // Each entry that forms part of the LFN contributes 13 UCS-2 characters, except the
                        // final one logically (physically first in the directory object) which may include
                        // a '0x0000' terminator.
                        uint16_t offset = (seqNumber - 1) * 13;
                        if (offset < ucs_max) {
                            uint8_t lastLogical = (entryType & 0x40u);
                            // Names are limited to 256 characters including the terminator.
                            size_t len = (lastLogical && seqNumber >= 0x14u) ? 9 : 13;
                            if (offset + len > ucs_max) {
                                len = ucs_max - offset;
                            }
                            // The UCS-2 name portion is scattered throughout the directory entry for
                            // compatibility with earlier systems.
                            (void)memcpy((uint8_t *)&ucs[offset], &dir_entry[1],
                                         ((len >= 5) ? 5 : len) * 2);
                            if (len > 5) {
                                (void)memcpy((uint8_t *)&ucs[offset + 5], &dir_entry[0xe],
                                             ((len >= 11) ? 6 : (len - 5)) * 2);
                                if (len > 11) {
                                    (void)memcpy((uint8_t *)&ucs[offset + 11], &dir_entry[0x1c],
                                                 (len - 11) * 2);
                                }
                            }
                            // Ensure that the returned name is NUL-terminated if there is space.
                            if (lastLogical && (ucs_max - offset > len)) {
                                ucs[offset + len] = 0;
                            }
                        }
                    }
                }
                // The LFN entries prefix the regular entry for a given object.
                hasLFN = true;
                entryWanted = false;
            } else {
                entryWanted = entryType && (entryType != 0x2e) && include_entry(entryFlags, flags);
                if (!entryWanted) {
                    // After a regular object that is rejected, reset the LFN flag for the following object.
                    hasLFN = false;
                }
            }
        }
        if (entryWanted) {
            uint32_t cluster =
                ((uint32_t)read16le(&dir_entry[0x14]) << 16) | read16le(&dir_entry[0x1a]);
            // the upper nibble of the cluster must be ignored; reserved for future use.
            cluster &= ~0xf0000000u;

            entry->flags = entryFlags;
            entry->entryType = dir_entry[0];
            // The short name of this file.
            (void)memcpy(entry->shortName, dir_entry, 8);
            // File extension for the short name.
            (void)memcpy(entry->shortExt, &dir_entry[8], 3);

            // Try to be helpful by reinstating the first character.
            if (entryFlags & DirEntryFlag_Deleted) {
                entry->shortName[0] = dir_entry[0xd];
            }
            // Also, since 0xe5 is used to mark a deleted entry, a filename that actually starts with
            // 0xe5 has historically been encoded using 0x05.
            if (entry->shortName[0] == 0x05) {
                entry->shortName[0] = 0xe5;
            }
            // If this object does not have a Long FileName but a buffer has been supplied, then
            // provide a conversion.
            if (ucs && !hasLFN) {
                generate_lfn(ucs, ucs_max, entry);
            }

            // See the design of the FAT file system for use/interpretation of these fields.
            entry->attribs = dir_entry[0xb];
            entry->userAttribs = dir_entry[0xc];
            entry->createdFine = dir_entry[0xd];
            entry->createdTime = read16le(&dir_entry[0xe]);
            entry->createdDate = read16le(&dir_entry[0x10]);
            entry->accessDate = read16le(&dir_entry[0x12]);
            entry->modifiedTime = read16le(&dir_entry[0x16]);
            entry->modifiedDate = read16le(&dir_entry[0x18]);

            // These fields are simply enough and important for file/directory access.
            entry->firstCluster = cluster;
            entry->dataLength = read32le(&dir_entry[0x1c]);
            return true;
        }
    } while (entryType);

    return false;
}

// Attempt to find an extant object (file/directory) with the given name in the specified directory;
// the search string is ASCIIZ but may be a Long FileName.
// The UCS-2 name may be retrieved in the event of a match.
bool dir_find(fs_utils_state_t *fs, fs_utils_dir_handle_t dh, fs_utils_dir_entry_t *entry,
              const char *name, uint16_t *ucs, size_t ucs_max)
{
    if (!dh_valid(fs, dh)) {
        return false;
    }
    while (dir_next(fs, dh, entry, DirFlags_Default, fs->buf.nameBuffer,
                    sizeof(fs->buf.nameBuffer) / 2)) {
        // Using the full name buffer here guarantees that 'dir_next' will have appended a NUL.
        if (!ucs2_char_compare(fs->buf.nameBuffer, name, ~0u)) {
            if (ucs) {
                ucs2_copy(ucs, fs->buf.nameBuffer, ucs_max);
            }
            return true;
        }
    }
    return false;
}

// Variant using full UCS-2 filename encoding.
bool dir_find_ucs2(fs_utils_state_t *fs, fs_utils_dir_handle_t dh, fs_utils_dir_entry_t *entry,
                   const uint16_t *ucs_name)
{
    if (!dh_valid(fs, dh)) {
        return false;
    }
    while (dir_next(fs, dh, entry, DirFlags_Default, fs->buf.nameBuffer,
                    sizeof(fs->buf.nameBuffer) / 2)) {
        // Using the full name buffer here guarantees that 'dir_next' will have appended a NUL.
        if (!ucs2_compare(fs->buf.nameBuffer, ucs_name, ~0u)) {
            return true;
        }
    }
    return false;
}

// Release access to the given directory.
void dir_close(fs_utils_state_t *fs, fs_utils_dir_handle_t dh)
{
    if (dh < FS_UTILS_MAX_DIRS) {
        fs->dirs[dh].flags = 0u;
    }
}

// Object name comparison; UCS-2 in each case. Case-sensitive matching.
int ucs2_compare(const uint16_t *ucs1, const uint16_t *ucs2, size_t len)
{
    while (len-- > 0) {
        uint16_t c2 = *ucs2++;
        uint16_t c1 = *ucs1++;
        // This handles the termination case too.
        if (!c1 || c1 != c2) {
            return (int)c1 - (int)c2;
        }
    }
    return 0;
}

// Object name comparison; ASCII character name against UCS-2; a convenience when matching against
// LFN entries using an ASCIIZ name.
int ucs2_char_compare(const uint16_t *ucs1, const char *s2, size_t len)
{
    while (len-- > 0) {
        uint8_t c2 = (uint8_t)*s2++;
        uint16_t c1 = *ucs1++;
        // This handles the termination case too.
        if (!c1 || c1 != c2) {
            return (int)c1 - (int)c2;
        }
    }
    return 0;
}

// Utility function that copies a UCS-2 name up to an including any terminator, copying no more
// than 'n' characters.
void ucs2_copy(uint16_t *d, const uint16_t *s, size_t n)
{
    if (n > 0u) {
        unsigned idx = 0u;
        uint16_t ch;
        do {
            ch = s[idx];
            d[idx++] = ch;
        } while (ch && idx < n);
    }
}

// Open the file described by the given directory entry.
fs_utils_file_handle_t file_open(fs_utils_state_t *fs, const fs_utils_dir_entry_t *entry)
{
    // Ensure that we have a file handle available
    fs_utils_file_handle_t fh = 0u;
    while (fs->files[fh].flags & FS_UTILS_FLAG_VALID) {
        if (++fh >= FS_UTILS_MAX_FILES) {
            return FS_UTILS_INVALID_FILE_HANDLE;
        }
    }
    // Initialise file state.
    fs->files[fh].flags = FS_UTILS_FLAG_VALID;
    fs->files[fh].offset = 0u;
    fs->files[fh].length = entry->dataLength;
    fs->files[fh].currCluster = entry->firstCluster;
    fs->files[fh].firstCluster = entry->firstCluster;
    if (fs->uart) {
        uprintf(fs->uart, "Opened file of 0x%x byte(s) at cluster 0x%x\n", entry->dataLength,
                entry->firstCluster);
    }
    return fh;
}

// Initiate read access to the given file and return a handle to the file, or InvalidFileHandle if
// the operation is unsuccessful.
//
// Variants accept either ASCIIZ (char) or full UCS-2 name (uint16_t).
fs_utils_file_handle_t file_open_str(fs_utils_state_t *fs, const char *name)
{
    // Maintain the pretence of supporting full pathnames; they may be supported at some point.
    if (*name == '/' || *name == '\\') {
        name++;
    }

    fs_utils_file_handle_t fh = FS_UTILS_INVALID_FILE_HANDLE;
    fs_utils_dir_handle_t dh = rootdir_open(fs);
    if (dh_valid(fs, dh)) {
        fs_utils_dir_entry_t entry;
        if (dir_find(fs, dh, &entry, name, NULL, 0u)) {
            fh = file_open(fs, &entry);
        }
        dir_close(fs, dh);
    }
    return fh;
}
fs_utils_file_handle_t file_open_ucs2(fs_utils_state_t *fs, const uint16_t *name)
{
    fs_utils_file_handle_t fh = FS_UTILS_INVALID_FILE_HANDLE;
    fs_utils_dir_handle_t dh = rootdir_open(fs);
    if (dh_valid(fs, dh)) {
        fs_utils_dir_entry_t entry;
        if (dir_find_ucs2(fs, dh, &entry, name)) {
            fh = file_open(fs, &entry);
        }
        dir_close(fs, dh);
    }
    return fh;
}

// Return the length of an open file, or a negative value if the file handle is invalid.
int64_t file_length(fs_utils_state_t *fs, fs_utils_file_handle_t fh)
{
    return fh_valid(fs, fh) ? (int64_t)fs->files[fh].length : -1;
}

// Set the read position within a file.
bool file_seek(fs_utils_state_t *fs, fs_utils_file_handle_t fh, uint32_t offset)
{
    if (!fh_valid(fs, fh)) {
        return 0u;
    }
    return object_seek(fs, &fs->files[fh], offset);
}

// Read data from a file at the supplied offset, reading the requested number of bytes.
size_t file_read(fs_utils_state_t *fs, fs_utils_file_handle_t fh, uint8_t buf[], size_t len)
{
    if (!fh_valid(fs, fh)) {
        return 0u;
    }
    return object_read(fs, &fs->files[fh], buf, len);
}

// Return a list of clusters holding the contents of this file, starting from the current file offset,
// and updating it upon return.
int64_t file_clusters(fs_utils_state_t *fs, fs_utils_file_handle_t fh, uint8_t *clusterShift,
                      uint32_t buf[], size_t len)
{
    // Check that the file handle is valid.
    if (!fh_valid(fs, fh)) {
        return -1;
    }
    // Indicate how many blocks form a cluster for this partition.
    *clusterShift = fs->blksPerClusterShift;
    // Run forwards from the current position, permitting incremental retrieval.
    uint32_t cluster = fs->files[fh].currCluster;
    // Ensure that the offset is aligned to the start of the cluster.
    uint32_t offset = fs->files[fh].offset & ~fs->clusterMask;
    size_t n = 0u;
    while (len-- > 0u && !end_of_chain(cluster)) {
        uint32_t nextCluster;
        *buf++ = cluster;
        n++;
        if (!cluster_next(fs, &nextCluster, cluster)) {
            break;
        }
        // Remember this position within the file.
        offset += fs->clusterBytes;
        fs->files[fh].offset = offset;
        fs->files[fh].currCluster = cluster;
        cluster = nextCluster;
    }
    return (int64_t)n;
}

// Finalise read access to the given file.
void file_close(fs_utils_state_t *fs, fs_utils_file_handle_t fh)
{
    if (fh_valid(fs, fh)) {
        fs->files[fh].flags = 0u;
    }
}

// Read Cylinder, Head and Sector ('CHS address'), as stored in a partition table entry.
inline void read_chs(uint16_t *c, uint8_t *h, uint8_t *s, const uint8_t *p)
{
    // Head numbers are 0-based.
    *h = p[0];
    // Note that sector numbers are 1-based.
    *s = (p[1] & 0x3fu);
    // Cylinder numbers are 0-based.
    *c = ((p[1] << 2) & 0x300u) | p[2];
}

// Utility function that converts Cylinder, Head, Sector (CHS) addressing into Logical Block Addressing
// (LBA), according to the specified disk geometry.
uint32_t chs_to_lba(uint16_t c, uint8_t h, uint8_t s, uint8_t nheads, uint8_t nsecs)
{
    // Notes: cylinder and head are zero-based but sector number is 1-based (0 is invalid).
    // CHS-addressed drives were limited to 255 heads and 63 sectors.
    if (h >= nheads || !s || s > nsecs) {
        return UINT32_MAX;
    }
    return ((c * nheads + h) * nsecs) + (s - 1);
}

// Read 32-bit Little Endian word.
inline uint32_t read32le(const uint8_t *p)
{
    return p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

// Read 16-bit Little Endian word.
inline uint16_t read16le(const uint8_t *p)
{
    return p[0] | ((uint16_t)p[1] << 8);
}

// private:
// We should perhaps convert to lower case only if the entire name is upper case; we do not have
// access to a 'tolower' implementation.
inline uint16_t as_lower_case(uint8_t ch)
{
    return (ch >= 'A' && ch <= 'Z') ? (ch - 'A' + 'a') : ch;
}

// Generate a Long FileName from a short form if no long form is available.
void generate_lfn(uint16_t *ucs, size_t ucs_max, const fs_utils_dir_entry_t *entry)
{
    unsigned idx = 0u;
    // Short name.
    while (ucs_max > 0u && idx < 8u && entry->shortName[idx] > 0x20u) {
        *ucs++ = as_lower_case(entry->shortName[idx++]);
        ucs_max--;
    }
    // Period separator between short name and extension.
    if (ucs_max > 0u && entry->shortExt[0u] > 0x20u) {
        *ucs++ = '.';
        ucs_max--;
    }
    // Short extension.
    idx = 0u;
    while (ucs_max > 0u && idx < 3u && entry->shortExt[idx] > 0x20u) {
        *ucs++ = as_lower_case(entry->shortExt[idx++]);
        ucs_max--;
    }
    // NUL termination.
    if (ucs_max > 0U) {
        *ucs = 0;
    }
}

// Decide whether an entry with the given flags shall be returned by a directory traversal.
inline bool include_entry(fs_utils_dir_entry_flags_t entryFlags, fs_utils_dir_flags_t flags)
{
    return (!(entryFlags & DirEntryFlag_Deleted) || (flags & DirFlag_IncludeDeleted)) &&
           (!(entryFlags & DirEntryFlag_Hidden) || (flags & DirFlag_IncludeHidden)) &&
           !(entryFlags & DirEntryFlag_VolumeLabel);
}
