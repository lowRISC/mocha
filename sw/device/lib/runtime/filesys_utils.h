// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Very simple layer for read access to the files within the root directory
 * of a FAT32 partition on an SD card.
 *
 * If a more sophisticated, feature-rich filing system layer including, e.g.
 * support for writing data, is required, there are a number of open source
 * implementations of FAT32 support available.
 *
 * The code will locate the first FAT32 partition, and only Master Boot Record (MBR)
 * partitioning is supported, which is how blanks microSD cards are shipped by
 * manufacturers, so avoid the use of GPT if reformatting.
 *
 * https://en.wikipedia.org/wiki/File_Allocation_Table#FAT32
 * https://en.wikipedia.org/wiki/Design_of_the_FAT_file_system
 */

#pragma once

#include "hal/uart.h"

// Some SD cards support only a 512-byte block size, and SPI mode transfers are
// always in terms of that anyway.
#define FS_UTILS_BYTES_PER_BLOCK_SHIFT (9u)
#define FS_UTILS_BLOCK_LEN             (1u << FS_UTILS_BYTES_PER_BLOCK_SHIFT)

// Number of entries in the block cache.
#define FS_UTILS_CACHE_ENTRIES (8u)
// Denotes an unused entry in the block cache.
#define FS_UTILS_INVALID_BLOCK (~(uint32_t)0u)

// Object state flags.
#define FS_UTILS_FLAG_VALID (1u << 31)

// Open file and directory limits.
#define FS_UTILS_MAX_FILES (4u)
#define FS_UTILS_MAX_DIRS  (2u)

// Invalid file handle, returned by a failed `file_open` call.
#define FS_UTILS_INVALID_FILE_HANDLE (0xffu)
// Invalid directory handle, returned by a failed 'dir_open' call.
#define FS_UTILS_INVALID_DIR_HANDLE  (0xffu)

// typedef union fs_utils_buf {
//   uint8_t dataBuffer[FS_UTILS_BLOCK_LEN];
//   uint16_t nameBuffer[0x100u];
// } fs_utils_buf_t;

// State information on an object being accessed; this may be either a file or a directory.
typedef struct fs_utils_obj_state {
  // Flags specifying validity/properties of this object.
  uint32_t flags;
  // Current offset (bytes) within the object.
  uint32_t offset;
  // Object length in bytes.
  uint32_t length;
  // Cluster number of the cluster holding the data at the current offset.
  uint32_t currCluster;
  // Cluster number of the first cluster holding the data for this object.
  uint32_t firstCluster;
} fs_utils_obj_state_t;

typedef struct fs_utils_state {
  // Access to debug/diagnostic logging.
  uart_t uart;
  // SD card access.
  spi_host_t spi;

  // Properties of the FAT32 partition.
  bool partValid;
  // The logical volume consists of sectors, which are not necessarily the same size as
  // the blocks used at (SD card) driver level.
  uint8_t bytesPerSectorShift;
  uint8_t secsPerClusterShift;
  uint8_t blksPerClusterShift;
  // First block of the FAT, relative to the medium start.
  uint32_t fatStart;
  // First block of the cluster heap.
  uint32_t clusterHeapStart;
  // First block of the root directory.
  uint32_t rootStart;
  // First cluster holding the root directory.
  uint32_t rootCluster;
  // Cluster size in bytes.
  uint32_t clusterBytes;
  // Mask used to extract the byte offset within the current cluster
  //   (= cluster size in bytes - 1).
  uint32_t clusterMask;

  // Single block buffer for use when reading partitions and FAT contents; this is a 512-byte
  // block as required by SPI mode SD card access, which is conveniently enough to hold the
  // longest LFN (255 UCS-2 characters, plus terminator) after initialisation.
  union {
    uint8_t dataBuffer[FS_UTILS_BLOCK_LEN];
    uint16_t nameBuffer[0x100u];
  } buf;

  // Block cache for next eviction.
  unsigned blockCacheNext;
  // Each block within the cache.
  struct {
    // Block number of the data occupying this cache entry (or FS_UTILS_INVALID_BLOCK).
    uint32_t block;
    // Data for this block.
    uint8_t buf[FS_UTILS_BLOCK_LEN];
  } blockCache[FS_UTILS_CACHE_ENTRIES];

  // Set of open files.
  fs_utils_obj_state_t files[FS_UTILS_MAX_FILES];

  // Set of open directories.
  fs_utils_obj_state_t dirs[FS_UTILS_MAX_DIRS];
} fs_utils_state_t;

// Opaque handle to an open file.
typedef uint8_t fs_utils_file_handle_t;

// Opaque handle to an open directory.
typedef uint8_t fs_utils_dir_handle_t;

// Flags specifying the type of directory access required.
typedef enum fs_utils_dir_flags {
  DirFlag_Raw            = 1u,
  DirFlag_IncludeDeleted = 2u,
  DirFlag_IncludeHidden  = 4u,

  DirFlags_Default = 0u,
} fs_utils_dir_flags_t;

// Directory entry type flags; this just makes the most common types of entries more accessible.
typedef enum fs_utils_dir_entry_flags {
  DirEntryFlag_Deleted      = 0x01u,
  DirEntryFlag_Hidden       = 0x02u,
  DirEntryFlag_VolumeLabel  = 0x04u,
  DirEntryFlag_Subdirectory = 0x08u,
  DirEntryFlag_HasLongName  = 0x10u
} fs_utils_dir_entry_flags_t;

// Description of an entry within a directory object.
typedef struct fs_utils_dir_entry {
  fs_utils_dir_entry_flags_t flags;
  uint8_t entryType;
  // Short name of this object (8.3 format)
  // Note: these fields are padded with spaces (0x20) and there is no NUL terminator.
  uint8_t shortName[8];
  uint8_t shortExt[8];
  // See the FAT file system design for the interpretation of the following fields.
  uint8_t attribs;
  uint8_t userAttribs;
  uint8_t createdFine;
  uint16_t createdTime;
  uint16_t createdDate;
  uint16_t modifiedTime;
  uint16_t modifiedDate;
  uint16_t accessDate;
  // Cluster number of the first cluster holding this object's data.
  uint32_t firstCluster;
  // Length of the object in bytes.
  uint32_t dataLength;
} fs_utils_dir_entry_t;

// 'Public' function declarations
bool init(fs_utils_state_t *state, spi_host_t spi, uart_t uart = NULL);
void fin(fs_utils_state_t *state);
uint32_t block_number(fs_utils_state_t *state, uint32_t cluster, uint32_t offset);
bool dh_valid(fs_utils_state_t *state, fs_utils_dir_handle_t dh);
bool fh_valid(fs_utils_state_t *state, fs_utils_file_handle_t fh);
fs_utils_dir_handle_t rootdir_open(fs_utils_state_t *state);
fs_utils_dir_handle_t dir_open(fs_utils_state_t *state, uint32_t cluster);
bool dir_next(fs_utils_state_t *state, fs_utils_dir_handle_t dh, fs_utils_dir_entry_t *entry, fs_utils_dir_flags_t flags = DirFlags_Default, uint16_t *ucs = NULL, size_t ucs_max = 0u);
bool dir_find(fs_utils_state_t *state, fs_utils_dir_handle_t dh, fs_utils_dir_entry_t *entry, const char *name, uint16_t *ucs = NULL, size_t ucs_max = 0u);
bool dir_find_usc2(fs_utils_state_t *state, fs_utils_dir_handle_t dh, fs_utils_dir_entry_t *entry, const uint16_t *ucs_name);
void dir_close(fs_utils_state_t *state, fs_utils_dir_handle_t dh);
int ucs2_compare(const uint16_t *ucs1, const uint16_t *ucs2, size_t len);
int ucs2_char_compare(const uint16_t *ucs1, const char *s2, size_t len);
void ucs2_copy(uint16_t *d, const uint16_t *s, size_t n);
fs_utils_file_handle_t file_open(fs_utils_state_t *state, const fs_utils_dir_entry_t *entry);
fs_utils_file_handle_t file_open_str(fs_utils_state_t *state, const char *name);
fs_utils_file_handle_t file_open_ucs2(fs_utils_state_t *state, const uint16_t *name);

// 'Private' function declarations
static void copy_bytes(uint8_t *dst, const uint8_t *src, size_t len);
static int block_ensure(fs_utils_state_t *state, uint32_t block);
static bool end_of_chain(uint32_t cluster);
static bool cluster_next(fs_utils_state_t *state, uint32_t &nextCluster, uint32_t cluster);
static bool object_seek(fs_utils_state_t *state, fs_utils_obj_state_t *obj, uint32_t offset);
static size_t object_read(fs_utils_state_t *state, fs_utils_obj_state_t *obj, uint8_t *buf, size_t len);
static uint8_t floor_log2(uint16_t n);

