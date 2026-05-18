// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "runtime/sdcard.h"
#include "hal/gpio.h"
#include "hal/mocha.h"
#include "hal/spi_host.h"
#include "hal/uart.h"
#include "runtime/bytedump.h"
#include "runtime/filesys_utils.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

// Lorem Ipsum sample text.
#include "lorem_text.h"

#define BLOCK_LEN 0x200

// Set this for manual operation rather than automated regression testing.
const bool manual = false;

// Set this to true to enable diagnostic logging.
const bool logging = false;

// Set this to true to emit the `lorem ipsum` sample text for capture and subsequent
// writing to a FAT32-formatted microSD card as `LOREM.IPS` within the root directory.
const bool emitText = false;

// Scratch workspace for reading file blocks or Long FileName.
uint8_t fileBuffer[BLOCK_LEN];

// Emit the UCS-2 long filename in a readable form; we cannot do this properly; we're just
// handling ASCII in practice.
static void write_str_ucs2(uart_t uart, const uint16_t *ucs, size_t ucs_max)
{
    size_t idx = 0u;
    while (idx < ucs_max && ucs[idx]) {
        uprintf(uart, "%c", printable_or_dot(ucs[idx]));
        idx++;
    }
}

static void write_test_result(uart_t uart, unsigned int failures, bool logging)
{
    if (logging) {
        if (failures == 0) {
            uprintf(uart, "PASS!\n");
        } else {
            uprintf(uart, "FAIL!\n");
        }
    }
}

// Compare a sequence of bytes against a reference, returning the number of mismatches.
static unsigned int compare_bytes(const char ref[], unsigned *offset, const uint8_t data[],
                                  size_t len)
{
    unsigned int mismatches = 0u;
    while (len-- > 0u) {
        // Compare retrieved data byte against reference text.
        uint8_t dch = *data++;
        char ch = ref[(*offset)++];
        // It's quite likely that the data stored on the card is LF-terminated rather than
        // the CR,LF termination that we expect, so we permit that and continue checking.
        if ((char)dch == '\n' && ch == '\r') {
            ch = ref[(*offset)++];
        }
        mismatches += (char)dch != ch;
    }
    return mismatches;
}

// Read and report the properties of the SD card itself (CSD and CID).
static unsigned int read_card_properties(bool *validCID, spi_host_t spi, uart_t uart, bool logging)
{
    unsigned int failures = 0u;
    uint8_t buf[16];
    for (size_t i = 0; i < sizeof(buf); i++) {
        buf[i] = 0xbd;
    }
    if (logging) {
        uprintf(uart, "  Reading Card Specific Data (CSD) ");
    }
    if (read_csd(spi, (uint8_t *)&buf, sizeof(buf), logging ? uart : NULL)) {
        if (logging) {
            uart_dump_bytes(uart, (const uint8_t *)&buf, sizeof(buf));
        }
        // The final byte contains a CRC7 field within its MSBs.
        uint8_t crc = 1u | (calc_crc7((const uint8_t *)&buf, sizeof(buf) - 1u) << 1);
        failures += (crc != buf[sizeof(buf) - 1u]);
    } else {
        failures++;
    }
    write_test_result(uart, failures, logging);

    for (size_t i = 0; i < sizeof(buf); i++) {
        buf[i] = 0xbd;
    }
    if (logging) {
        uprintf(uart, "  Reading Card Identification (CID) ");
    }
    *validCID = false;
    if (read_cid(spi, (uint8_t *)&buf, sizeof(buf), logging ? uart : NULL)) {
        if (logging) {
            uart_dump_bytes(uart, (const uint8_t *)&buf, sizeof(buf));
        }
        // The final byte contains a CRC7 field within its MSBs.
        uint8_t crc = 1u | (calc_crc7((const uint8_t *)&buf, sizeof(buf) - 1u) << 1);
        failures += (crc != buf[sizeof(buf) - 1u]);
        // Check that the manufacturer ID is non-zero and the OEM/Application ID contains two
        // valid ASCII characters.
        if (buf[0] && buf[1] >= 0x20 && buf[1] < 0x7f && buf[2] >= 0x20 && buf[2] < 0x7f) {
            *validCID = true;
        }
    } else {
        failures++;
    }
    write_test_result(uart, failures, logging);

    return failures;
}

/**
 * Run the set of SD card tests; test card presence, read access to the card itself
 * and then the data stored within the flash. The test expects a FAT32-formatted
 * SD card with a sample file called `LOREM.IPS` in the root directory.
 *
 * Use UART for logging as it is the only option at present.
 */
bool sdcard_tests(spi_host_t spi, gpio_t gpio, uart_t uart)
{
    // Have we been asked to emit the sample text?
    if (emitText) {
        uprintf(uart, "Capture everything between the dotted lines, being careful not "
                      "to introduce any additional line breaks.\n");
        uprintf(uart, "--------\n");
        uprintf(uart, lorem_text);
        uprintf(uart, "--------\n");
        uprintf(uart, "Each of these single-line paragraphs shall be CR,LF terminated "
                      "and followed by a blank line.\n");
        uprintf(uart,
                "This includes the final one, and thus the file itself ends with a blank line.\n");
        uprintf(uart, "The file should be 4,210 bytes in length.\n");
    }

    // microSD card detection bit is on GPIO input 9 (0-indexed).
    // Input is forced low if card is present, or pulled high if absent.
    const unsigned detBit = 9u;

    unsigned int failures = 0u;
    if (gpio_read_pin(gpio, detBit)) {
        if (manual) {
            // Wait until a card is detected.
            uprintf(uart, "Please insert a microSD card into the slot...\n");
            while (gpio_read_pin(gpio, detBit)) {
            }
        } else {
            uprintf(uart, "No microSD card detected\n");
            failures++;
        }
    }
    if (!gpio_read_pin(gpio, detBit)) {
        bool validCID;

        // Initialise SD card access
        sdcard_init(spi, logging ? uart : NULL);

        if (logging) {
            uprintf(uart, "Reading card properties\n");
        }
        failures += read_card_properties(&validCID, spi, uart, logging);

        // The CI system presently does not have a valid microSD card image and properties in
        // simulation. We have already tested SPI traffic so if we haven't read a valid CID,
        // skip the block level/filing system testing.
        if (validCID) {
            if (logging) {
                uprintf(uart, "Reading card contents\n");
            }
            // Filesystem state struct is too big for the stack, so statically allocate it.
            static fs_utils_state_t fs;

            failures += !fs_utils_init(&fs, spi, logging ? uart : NULL);
            write_test_result(uart, failures, logging);

            if (!failures) {
                // List the files and subdirectories in the root directory.
                if (logging) {
                    uprintf(uart, "Reading root directory\n");
                }
                fs_utils_dir_handle_t dh = rootdir_open(&fs);
                if (dh == FS_UTILS_INVALID_DIR_HANDLE) {
                    failures++;
                } else {
                    uint16_t *ucs = (uint16_t *)fileBuffer;
                    const size_t ucs_max = sizeof(fileBuffer) / 2;
                    fs_utils_dir_entry_t entry;
                    while (dir_next(&fs, dh, &entry, DirFlags_Default, ucs, ucs_max)) {
                        if (logging) {
                            uprintf(uart, "'");
                            write_str_ucs2(uart, ucs, ucs_max);
                            uprintf(uart, "' : length 0x%x cluster 0x%x\n", entry.dataLength,
                                    entry.firstCluster);
                        }
                    }
                    dir_close(&fs, dh);
                }
                write_test_result(uart, failures, logging);

                // Locate and check the LOREM.IPS test file in the root directory.
                fs_utils_file_handle_t fh = file_open_str(&fs, "lorem.ips");
                if (fh == FS_UTILS_INVALID_FILE_HANDLE) {
                    uprintf(uart, "Unable to locate file\n");
                    failures++;
                } else {
                    // Determine the length of the file.
                    int64_t fileLen = file_length(&fs, fh);
                    if (fileLen < 0) {
                        uprintf(uart, "Failed to read file length\n");
                        failures++;
                    } else {
                        if (logging) {
                            uprintf(uart, "File is 0x%x byte(s)\n", (unsigned int)fileLen);
                        }
                    }
                    uint32_t sampleOffset = 0u;
                    while (fileLen > 0 && sampleOffset < sizeof(lorem_text)) {
                        // Work out how many bytes we can compare.
                        uint32_t chunkLen = ((uint64_t)fileLen >= sizeof(fileBuffer)) ?
                                                sizeof(fileBuffer) :
                                                fileLen;
                        if (chunkLen > sizeof(lorem_text) - sampleOffset) {
                            chunkLen = sizeof(lorem_text) - sampleOffset;
                        }
                        // Read data from the SD card into our buffer.
                        size_t read = file_read(&fs, fh, fileBuffer, chunkLen);
                        if (read != chunkLen) {
                            // We did not read the expected number of bytes.
                            uprintf(uart,
                                    "File read did not return the requested number of bytes\n");
                            failures++;
                        }
                        if (logging) {
                            uart_dump_bytes(uart, (const uint8_t *)fileBuffer, chunkLen);
                        }
                        // Compare this data against the sample text.
                        failures += compare_bytes(lorem_text, &sampleOffset, fileBuffer, chunkLen);
                        fileLen -= chunkLen;
                    }
                    if (logging) {
                        uprintf(uart, "Done text comparison\n");
                    }
                    // If we have not compared the entire file, count that as a failure.
                    failures += (fileLen > 0);
                    file_close(&fs, fh);
                }
                write_test_result(uart, failures, logging);
            } else {
                uprintf(uart, "No valid Master Boot Record found (signature not detected)\n");
                failures++;
            }
        }
    }
    write_test_result(uart, failures, logging);
    return failures == 0;
}


bool test_main(uart_t console)
{
    // The SPI controller talks to the microSD card in SPI mode.
    spi_host_t spi = mocha_system_spi_host();
    spi_host_init(spi);

    // We need to use the GPIO to detect card presence.
    gpio_t gpio = mocha_system_gpio();

    // Run tests
    return sdcard_tests(spi, gpio, console);
}
