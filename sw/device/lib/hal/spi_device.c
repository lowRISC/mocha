// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/spi_device.h"
#include "hal/mmio.h"
#include "hal/reg_field.h"
#include <stdbool.h>
#include <stdint.h>

bool spi_device_interrupt_is_pending(spi_device_t spi_device, uint8_t intr_id)
{
    if (intr_id > SPI_DEVICE_MAX_INTR) {
        return false;
    }
    return ((DEV_READ(spi_device + SPI_DEVICE_INTR_STATE_REG) & (1 << intr_id)) != 0);
}

void spi_device_interrupt_clear(spi_device_t spi_device, uint8_t intr_id)
{
    if (intr_id <= SPI_DEVICE_MAX_INTR) {
        DEV_WRITE(spi_device + SPI_DEVICE_INTR_STATE_REG, 1 << intr_id);
    }
}

void spi_device_interrupt_disable_all(spi_device_t spi_device)
{
    DEV_WRITE(spi_device + SPI_DEVICE_INTR_ENABLE_REG, 0);
}

void spi_device_interrupt_enable(spi_device_t spi_device, uint8_t intr_id)
{
    if (intr_id <= SPI_DEVICE_MAX_INTR) {
        DEV_WRITE(spi_device + SPI_DEVICE_INTR_ENABLE_REG,
                  DEV_READ(spi_device + SPI_DEVICE_INTR_ENABLE_REG) | (1 << intr_id));
    }
}

void spi_device_interrupt_disable(spi_device_t spi_device, uint8_t intr_id)
{
    if (intr_id <= SPI_DEVICE_MAX_INTR) {
        DEV_WRITE(spi_device + SPI_DEVICE_INTR_ENABLE_REG,
                  DEV_READ(spi_device + SPI_DEVICE_INTR_ENABLE_REG) & ~(1 << intr_id));
    }
}

void spi_device_interrupt_trigger(spi_device_t spi_device, uint8_t intr_id)
{
    if (intr_id <= SPI_DEVICE_MAX_INTR) {
        DEV_WRITE(spi_device + SPI_DEVICE_INTR_TEST_REG, 1 << intr_id);
    }
}

void spi_device_4b_addr_mode_enable_set(spi_device_t spi_device, bool enable)
{
    DEV_WRITE(spi_device + SPI_DEVICE_ADDR_MODE_REG, (uint32_t)enable);

    // Wait for change to take effect
    while (DEV_READ(spi_device + SPI_DEVICE_ADDR_MODE_REG) & SPI_DEVICE_ADDR_MODE_PENDING_MASK) {
    }
}

bool spi_device_4b_addr_mode_enable_get(spi_device_t spi_device)
{
    return ((DEV_READ(spi_device + SPI_DEVICE_ADDR_MODE_REG) & SPI_DEVICE_ADDR_MODE_4B_EN_MASK) ==
            1);
}

void spi_device_flash_status_set(spi_device_t spi_device, uint32_t flash_status)
{
    DEV_WRITE(spi_device + SPI_DEVICE_FLASH_STATUS_REG, flash_status);
}

uint32_t spi_device_flash_status_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_FLASH_STATUS_REG);
}

void spi_device_jedec_cc_set(spi_device_t spi_device, uint8_t cc, uint8_t num_cc)
{
    DEV_WRITE(spi_device + SPI_DEVICE_JEDEC_CC_REG,
              ((uint32_t)cc << SPI_DEVICE_JEDEC_CC) |
                  ((uint32_t)num_cc << SPI_DEVICE_JEDEC_NUM_CC));
}

uint16_t spi_device_jedec_cc_get(spi_device_t spi_device)
{
    return (uint16_t)DEV_READ(spi_device + SPI_DEVICE_JEDEC_CC_REG);
}

void spi_device_jedec_id_set_raw(spi_device_t spi_device, uint32_t data)
{
    DEV_WRITE(spi_device + SPI_DEVICE_JEDEC_ID_REG, data);
}

void spi_device_jedec_id_set(spi_device_t spi_device, bool rom_bootstrap, uint8_t chip_rev,
                             uint8_t chip_gen, uint8_t density, uint8_t manufacturer_id)
{
    uint32_t reg = ((uint32_t)rom_bootstrap) << SPI_DEVICE_ROM_BOOTSTRAP;
    reg = reg | (((uint32_t)chip_rev & SPI_DEVICE_CHIP_REV_MASK) << SPI_DEVICE_CHIP_REV);
    reg = reg | (((uint32_t)chip_gen & SPI_DEVICE_CHIP_GEN_MASK) << SPI_DEVICE_CHIP_GEN);
    reg = reg | (((uint32_t)density) << SPI_DEVICE_DENSITY);
    reg = reg | (((uint32_t)manufacturer_id) << SPI_DEVICE_MANUFACTURER_ID);
    spi_device_jedec_id_set_raw(spi_device, reg);
}

uint32_t spi_device_jedec_id_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_JEDEC_ID_REG);
}

void spi_device_mailbox_addr_set(spi_device_t spi_device, uint32_t addr)
{
    DEV_WRITE(spi_device + SPI_DEVICE_MAILBOX_ADDR_REG, addr);
}

uint32_t spi_device_mailbox_addr_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_MAILBOX_ADDR_REG);
}

uint32_t spi_device_upload_status_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_UPLOAD_STATUS_REG);
}

uint32_t spi_device_upload_status2_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_UPLOAD_STATUS2_REG);
}

uint32_t spi_device_upload_cmdfifo_read(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_UPLOAD_CMDFIFO_REG);
}

uint32_t spi_device_upload_addrfifo_read(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_UPLOAD_ADDRFIFO_REG);
}

void spi_device_cmd_filter_set(spi_device_t spi_device, uint32_t offset, uint32_t data)
{
    if (offset < SPI_DEVICE_CMD_FILTER_0_REG || offset > SPI_DEVICE_CMD_FILTER_7_REG) {
        return;
    }

    DEV_WRITE(spi_device + offset, data);
}

uint32_t spi_device_cmd_filter_get(spi_device_t spi_device, uint32_t offset)
{
    if (offset < SPI_DEVICE_CMD_FILTER_0_REG || offset > SPI_DEVICE_CMD_FILTER_7_REG) {
        return 0;
    }

    return DEV_READ(spi_device + offset);
}

void spi_device_cmd_info_set_raw(spi_device_t spi_device, uint32_t offset, uint32_t data)
{
    if (offset < SPI_DEVICE_CMD_INFO_0_REG || offset > SPI_DEVICE_CMD_INFO_23_REG) {
        return;
    }

    DEV_WRITE(spi_device + offset, data);
}

void spi_device_cmd_info_set(spi_device_t spi_device, uint32_t offset, uint8_t opcode, bool address,
                             uint8_t dummy_cycles, bool handled_in_sw)
{
    if (offset < SPI_DEVICE_CMD_INFO_0_REG || offset > SPI_DEVICE_CMD_INFO_23_REG) {
        return;
    }

    uint32_t reg = 0;
    reg = reg | (opcode << SPI_DEVICE_CMD_OPCODE);

    if (address) {
        reg = reg | ((SPI_DEVICE_CMD_ADDR_MODE_ADDR_3B & SPI_DEVICE_CMD_ADDR_MODE_MASK)
                     << SPI_DEVICE_CMD_ADDR_MODE);
    } else {
        reg = reg | ((SPI_DEVICE_CMD_ADDR_MODE_ADDR_DISABLED & SPI_DEVICE_CMD_ADDR_MODE_MASK)
                     << SPI_DEVICE_CMD_ADDR_MODE);
    }

    if (dummy_cycles > 0) {
        reg = reg |
              (((dummy_cycles - 1) & SPI_DEVICE_CMD_DUMMY_SIZE_MASK) << SPI_DEVICE_CMD_DUMMY_SIZE);
        reg = reg | (1 << SPI_DEVICE_CMD_DUMMY_EN);
    }

    if (handled_in_sw) {
        reg = reg | (1 << SPI_DEVICE_CMD_UPLOAD);
        reg = reg | (1 << SPI_DEVICE_CMD_BUSY);
    }

    reg = reg | (1 << SPI_DEVICE_CMD_VALID);

    spi_device_cmd_info_set_raw(spi_device, offset, reg);
}

uint32_t spi_device_cmd_info_get(spi_device_t spi_device, uint32_t offset)
{
    if (offset < SPI_DEVICE_CMD_INFO_0_REG || offset > SPI_DEVICE_CMD_INFO_23_REG) {
        return 0;
    }

    return DEV_READ(spi_device + offset);
}

void spi_device_cmd_info_write_enable_set_raw(spi_device_t spi_device, uint32_t data)
{
    DEV_WRITE(spi_device + SPI_DEVICE_CMD_INFO_WREN_REG, data);
}

void spi_device_cmd_info_write_enable_set(spi_device_t spi_device, uint8_t opcode)
{
    uint32_t reg = 0;
    reg = reg | (opcode << SPI_DEVICE_CMD_OPCODE);
    reg = reg | (1 << SPI_DEVICE_CMD_VALID);

    spi_device_cmd_info_write_enable_set_raw(spi_device, reg);
}

uint32_t spi_device_cmd_info_write_enable_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_CMD_INFO_WREN_REG);
}

void spi_device_cmd_info_write_disable_set_raw(spi_device_t spi_device, uint32_t data)
{
    DEV_WRITE(spi_device + SPI_DEVICE_CMD_INFO_WRDI_REG, data);
}

void spi_device_cmd_info_write_disable_set(spi_device_t spi_device, uint8_t opcode)
{
    uint32_t reg = 0;
    reg = reg | (opcode << SPI_DEVICE_CMD_OPCODE);
    reg = reg | (1 << SPI_DEVICE_CMD_VALID);

    spi_device_cmd_info_write_disable_set_raw(spi_device, reg);
}

uint32_t spi_device_cmd_info_write_disable_get(spi_device_t spi_device)
{
    return DEV_READ(spi_device + SPI_DEVICE_CMD_INFO_WRDI_REG);
}

bool spi_device_flash_read_buffer_write(spi_device_t spi_device, uint32_t offset, uint32_t data)
{
    // Ignore unaligned writes
    if ((offset % sizeof(uint32_t)) != 0) {
        return false;
    }
    // Ignore writes outside read buffer
    if (offset >= SPI_DEVICE_READ_BUFFER_NUM_BYTES) {
        return false;
    }
    DEV_WRITE(spi_device + SPI_DEVICE_EGRESS_BUFFER_OFFSET + SPI_DEVICE_READ_BUFFER_OFFSET + offset,
              data);
    return true;
}

uint32_t spi_device_flash_payload_buffer_read(spi_device_t spi_device, uint32_t offset)
{
    // Ignore unaligned reads
    if ((offset % sizeof(uint32_t)) != 0) {
        return 0;
    }
    // Ignore reads outside payload buffer
    if (offset >= SPI_DEVICE_PAYLOAD_AREA_NUM_BYTES) {
        return 0;
    }
    return DEV_READ(
        spi_device + SPI_DEVICE_INGRESS_BUFFER_OFFSET + SPI_DEVICE_PAYLOAD_AREA_OFFSET + offset);
}

void spi_device_sfdp_table_init(spi_device_t spi_device)
{
    // Prepare pointer to SFDP area in egress buffer
    void *buf_ptr = spi_device + SPI_DEVICE_EGRESS_BUFFER_OFFSET + SPI_DEVICE_SFDP_AREA_OFFSET;

    // clang-format off

    // Write SFDP header 1st word
    // [31: 0]: SFDP signature that indicates the presence of a SFDP table (JESD216F 6.2.1)
    DEV_WRITE(buf_ptr, SPI_DEVICE_SFDP_SIGNATURE);
    buf_ptr += sizeof(uint32_t);

    // Write SFDP header 2nd word
    // [ 7: 0]: SFDP minor revision number (JESD216F 6.2.2)
    // [15: 8]: SFDP major revision number (JESD216F 6.2.2)
    // [23:16]: Number of parameter headers, zero-based (JESD216F 6.2.2)
    // [31:24]: SFDP access protocol (JESD216F 6.2.3)
    DEV_WRITE(buf_ptr,
              reg32_field( 7,  0, SPI_DEVICE_SFDP_MINOR_REVISION) |
              reg32_field(15,  8, SPI_DEVICE_SFDP_MAJOR_REVISION) |
              reg32_field(23, 16, SPI_DEVICE_SFDP_PARAM_COUNT) |
              reg32_field(31, 24, SPI_DEVICE_SFDP_ACCESS_PROTOCOL));
    buf_ptr += sizeof(uint32_t);

    // Write Basic Flash Parameters Table (BFPT) parameter header 1st word
    // [ 7: 0]: LSB of the parameter ID that indicates parameter table ownership and type (JESD216F 6.3.1, 6.3.3)
    // [15: 8]: Parameter table minor revision number (JESD216F 6.3.1)
    // [23:16]: Parameter table major revision number (JESD216F 6.3.1)
    // [31:24]: Length of the parameter table in words, one-based (JESD216F 6.3.1)
    DEV_WRITE(buf_ptr,
              reg32_field( 7,  0, SPI_DEVICE_BFPT_PARAM_ID_LSB) |
              reg32_field(15,  8, SPI_DEVICE_BFPT_MINOR_REVISION) |
              reg32_field(23, 16, SPI_DEVICE_BFPT_MAJOR_REVISION) |
              reg32_field(31, 24, SPI_DEVICE_BFPT_NUM_WORDS));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT parameter header 2nd word
    // [23: 0]: Word-aligned byte offset of the corresponding parameter table from the start of the SFDP table (JESD216F 6.3.2)
    // [31:24]: MSB of the parameter ID that indicates parameter table ownership and type (JESD216F 6.3.2, 6.3.3)
    DEV_WRITE(buf_ptr,
              reg32_field(23,  0, 4) |
              reg32_field(31, 24, SPI_DEVICE_BFPT_PARAM_ID_MSB));
    buf_ptr += sizeof(uint32_t);

    // Note: Words below are numbered starting from 1 to match JESD216F. Some fields
    // that are not supported by OpenTitan are merged for the sake of conciseness.

    // Write BFPT 1st word
    // [31:23]: Unused (all 1s)
    // [22:19]: (1S-1S-4S) (1S-4S-4S) (1S-2S-2S) DTR Clock (not supported: 0x0)
    // [18:17]: Address bytes (3-byte only addressing: 0x0)
    // [16:16]: (1S-1S-2S) (not supported: 0x0)
    // [15: 8]: 4 KiB erase instruction (0x20)
    // [ 7: 5]: Unused (all 1s)
    // [ 4: 4]: Write enable instruction (use 0x06 for WREN: 0x1)
    // [ 3: 3]: Volatile block protect bits (solely volatile: 0x1)
    // [ 2: 2]: Write granularity (buffer >= 64 B: 0x1)
    // [ 1: 0]: Block/sector erase sizes (uniform 4 KiB erase: 0x1)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 23, UINT32_MAX) |
              reg32_field(22, 19, 0) |
              reg32_field(18, 17, 0x0) |
              reg32_field(16, 16, 0) |
              reg32_field(15,  8, SPI_DEVICE_OPCODE_SECTOR_ERASE) |
              reg32_field( 7,  5, UINT32_MAX) |
              reg32_field( 4,  4, 0x1) |
              reg32_field( 3,  3, 0x1) |
              reg32_field( 2,  2, 0x1) |
              reg32_field( 1,  0, 0x1));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 2nd Word
    // [31:31]: Density greater than 2 Gib (0x0)
    // [30: 0]: Flash memory density in bits, zero-based (0x7fffff)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 31, 0x0) |
              reg32_field(30,  0, MOCHA_SPI_DEVICE_DENSITY_BITS - 1));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 3rd Word
    // [31: 0]: Fast read (1S-4S-4S) (1S-1S-4S) (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 4th Word
    // [31: 0]: Fast read (1S-1S-2S) (1S-2S-2S) (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 5th Word
    // [31: 5]: Reserved (all 1s)
    // [ 4: 4]: Fast read (4S-4S-4S) support (not supported, 0x0)
    // [ 3: 1]: Reserved (all 1s)
    // [ 0: 0]: Fast read (2S-2S-2S) support (not supported, 0x0)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 5, UINT32_MAX) |
              reg32_field( 4, 4, 0x0) |
              reg32_field( 3, 1, UINT32_MAX) |
              reg32_field( 0, 0, 0x0));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 6th Word
    // [31:16]: Fast read (2S-2S-2S) (not supported, 0x0)
    // [15: 0]: Reserved (all 1s)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 16, 0x0) |
              reg32_field(15,  0, UINT32_MAX));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 7th Word
    // [31:16]: Fast read (4S-4S-4S) (not supported, 0x0)
    // [15: 0]: Reserved (all 1s)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 16, 0x0) |
              reg32_field(15,  0, UINT32_MAX));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 8th Word
    // [31:16]: Erase type 2 instruction and size (not supported, 0x0)
    // [15: 8]: Erase type 1 instruction (0x20)
    // [ 7: 0]: Erase type 1 size (4 KiB, 2^N bytes, N = 0x0c)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 16, 0x0) |
              reg32_field(15,  8, SPI_DEVICE_OPCODE_SECTOR_ERASE) |
              reg32_field( 7,  0, 0x0C));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 9th Word
    // [31: 0]: Erase type 4 and 3 (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 10th Word
    // [31:11]: Erase 4,3,2 typical time (not supported, 0x0)
    // [10: 9]: Erase type 1 time unit (16 ms, 0x1)
    // [ 8: 4]: Erase type 1 time count, zero-based (0x8)
    //          formula: (count + 1) * unit
    //          (8 + 1) * 16 ms = 144 ms
    // [ 3: 0]: Max erase time multiplier, zero-based (0x6)
    //          formula: 2 * (multiplier + 1) * erase_time
    DEV_WRITE(buf_ptr,
              reg32_field(31, 11, 0x0) |
              reg32_field(10,  9, 0x1) |
              reg32_field( 8,  4, 0x8) |
              reg32_field( 3,  0, 0x6));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 11th Word
    // [31:31]: Reserved (all 1s)
    // [30:29]: Chip erase time units (16 ms, 0x0)
    // [28:24]: Chip erase time count, zero-based (0xb)
    //          formula: (count + 1) * unit
    //          (11 + 1) * 16 ms = 192 ms
    // [23:23]: Additional byte program time units (8 us, 0x1)
    // [22:19]: Additional byte program time count, zero-based (0x5)
    //          formula: (count + 1) * unit
    //          (5 + 1) * 8 us = 48 us
    // [18:18]: First byte program time unit (8 us, 0x1)
    // [17:14]: First byte program time count, zero-based (0x5)
    //          formula: (count + 1) * unit
    //          (5 + 1) * 8 us = 48 us
    // [13:13]: Page program time unit (64 us, 0x1)
    // [12: 8]: Page program time count, zero-based (0xb)
    //          formula: (count + 1) * unit
    //          (11 + 1) * 64 us = 768 us
    // [ 7: 4]: Page size, 2^N (0x8)
    // [ 3: 0]: Max program time multiplier, zero-based (0x0)
    //          formula: 2 * (multiplier + 1) * program_time
    DEV_WRITE(buf_ptr,
              reg32_field(31, 31, UINT32_MAX) |
              reg32_field(30, 29, 0x0) |
              reg32_field(28, 24, 0xB) |
              reg32_field(23, 23, 0x1) |
              reg32_field(22, 19, 0x5) |
              reg32_field(18, 18, 0x1) |
              reg32_field(17, 14, 0x5) |
              reg32_field(13, 13, 0x1) |
              reg32_field(12,  8, 0xB) |
              reg32_field( 7,  4, 0x8) |
              reg32_field( 3,  0, 0x0));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 12th Word
    // [31:31]: Suspend/Resume supported (not supported, 0x1)
    // [30: 9]: Suspend/Resume latencies for erase & program (not supported, 0x0)
    // [ 8: 8]: Reserved (all 1s)
    // [ 7: 0]: Prohibited ops during suspend (not supported, 0x0)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 31, 0x1) |
              reg32_field(30,  9, 0x0) |
              reg32_field( 8,  8, UINT32_MAX) |
              reg32_field( 7,  0, 0x0));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 13th Word
    // [31: 0]: Erase/program suspend/resume instructions (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 14th Word
    // [31:31]: Deep powerdown support (not supported, 0x1)
    // [30: 8]: Deep powerdown instructions and delay (not supported, 0x0)
    // [ 7: 2]: Busy polling (bit 0 using 0x05 instruction, 0x1)
    // [ 1: 0]: Reserved (all 1s)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 31, 0x1) |
              reg32_field(30,  8, 0x0) |
              reg32_field( 7,  2, 0x1) |
              reg32_field( 1,  0, UINT32_MAX));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 15th Word
    // [31:24]: Reserved (all 1s)
    // [23: 0]: Hold, QE, (4S-4S-4S), 0-4-4 (not supported, 0x0)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 24, UINT32_MAX) |
              reg32_field(23,  0, 0x0));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 16th Word
    // [31:14]: 4-Byte addressing (not supported, 0x0)
    // [13: 8]: Soft-reset (0x66/0x99 sequence, 0x10)
    // [ 7: 7]: Reserved
    // [ 6: 0]: Status register (read-only, 0x0)
    DEV_WRITE(buf_ptr,
              reg32_field(31, 14, 0x0) |
              reg32_field(13,  8, 0x10) |
              reg32_field( 7,  7, UINT32_MAX) |
              reg32_field( 6,  0, 0x0));
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 17th Word
    // [31:  0]: Fast read (1S-8S-8S) (1S-1S-8S) (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 18th Word
    // [31,  0]: Data strobe, SPI protocol reset, etc. (not supported, 0x0)
    //
    // Note: Reserved fields of this word should be 0 (JESD216F 6.4.21).
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 19th Word
    // [31,  0]: Octable enable, (8D-8D-8D), 0-8-8 mode (not suported, 0x0)
    //
    // Note: Reserved fields of this word should be 0 (JESD216F 6.4.22).
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 20th Word
    // [31,  0]: Max (8S-8S-8S) (4D-4D-4D) (4S-4S-4S) speed
    //           (not supported, 0xffffffff)
    DEV_WRITE(buf_ptr, UINT32_MAX);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 21st Word
    // [31,  0]: Fast read support for various modes (not supported, 0x0)
    //
    // Note: Reserved fields of this word should be 0 (JESD216F 6.4.24).
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 22nd Word
    // [31,  0]: Fast read (1S-1D-1D) (1S-2D-2D) (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // Write BFPT 23rd Word
    // [31,  0]: Fast read (1S-4D-4D) (4S-2D-2D) (not supported, 0x0)
    DEV_WRITE(buf_ptr, 0);
    buf_ptr += sizeof(uint32_t);

    // clang-format on

    // Fill the remaining space with `0xff`s.
    while (buf_ptr < spi_device + SPI_DEVICE_EGRESS_BUFFER_OFFSET + SPI_DEVICE_SFDP_AREA_OFFSET +
                         SPI_DEVICE_SFDP_AREA_NUM_BYTES) {
        DEV_WRITE(buf_ptr, UINT32_MAX);
        buf_ptr += sizeof(uint32_t);
    }
}

void spi_device_init(spi_device_t spi_device)
{
    spi_device_4b_addr_mode_enable_set(spi_device, false);
    spi_device_jedec_cc_set(spi_device, MOCHA_SPI_DEVICE_JEDEC_CC, MOCHA_SPI_DEVICE_JEDEC_CC_COUNT);
    spi_device_jedec_id_set(spi_device, MOCHA_SPI_DEVICE_ROM_BOOTSTRAP, MOCHA_SPI_DEVICE_CHIP_REV,
                            MOCHA_SPI_DEVICE_CHIP_GEN, MOCHA_SPI_DEVICE_DENSITY_BYTES_LOG2,
                            MOCHA_SPI_DEVICE_MANUFACTURER_ID);
    spi_device_sfdp_table_init(spi_device);
    spi_device_flash_status_set(spi_device, 0);

    // Configure commands
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_0_REG, SPI_DEVICE_OPCODE_READ_STATUS,
                            false, 0, false);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_3_REG, SPI_DEVICE_OPCODE_READ_JEDEC_ID,
                            false, 0, false);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_4_REG, SPI_DEVICE_OPCODE_READ_SFDP,
                            true, 8, false);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_5_REG, SPI_DEVICE_OPCODE_READ_DATA,
                            true, 0, false);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_11_REG, SPI_DEVICE_OPCODE_CHIP_ERASE,
                            false, 0, true);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_12_REG, SPI_DEVICE_OPCODE_SECTOR_ERASE,
                            true, 0, true);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_13_REG, SPI_DEVICE_OPCODE_PAGE_PROGRAM,
                            true, 0, true);
    spi_device_cmd_info_set(spi_device, SPI_DEVICE_CMD_INFO_14_REG, SPI_DEVICE_OPCODE_RESET, false,
                            0, true);
    // Configure WRITE_ENABLE and WRITE_DISABLE commands
    spi_device_cmd_info_write_enable_set(spi_device, SPI_DEVICE_OPCODE_WRITE_ENABLE);
    spi_device_cmd_info_write_disable_set(spi_device, SPI_DEVICE_OPCODE_WRITE_DISABLE);
}

spi_device_cmd_t spi_device_cmd_get(spi_device_t spi_device)
{
    // Set return defaults
    spi_device_cmd_t cmd = {
        .status = 0, .opcode = 0x0, .address = UINT32_MAX, .payload_byte_count = 0
    };

    // Wait for software-handled command
    while (!spi_device_interrupt_is_pending(spi_device, SPI_DEVICE_INTR_UPLOAD_CMDFIFO_NOT_EMPTY)) {
    }

    // Clear interrupt
    spi_device_interrupt_clear(spi_device, SPI_DEVICE_INTR_UPLOAD_CMDFIFO_NOT_EMPTY);

    // Check for payload overflow
    if (spi_device_interrupt_is_pending(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW)) {
        cmd.status = 1;
        spi_device_interrupt_clear(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);
        return cmd;
    }

    // Get opcode
    cmd.opcode = (uint8_t)spi_device_upload_cmdfifo_read(spi_device);

    // Get address
    if ((spi_device_upload_status_get(spi_device) &
         SPI_DEVICE_UPLOAD_STATUS_ADDRFIFO_NOTEMPTY_MASK) != 0) {
        cmd.address = spi_device_upload_addrfifo_read(spi_device);
    } else {
        // No address
        cmd.address = UINT32_MAX;
    }

    // Get payload size
    cmd.payload_byte_count = (uint16_t)(spi_device_upload_status2_get(spi_device) &
                                        SPI_DEVICE_UPLOAD_STATUS2_PAYLOAD_DEPTH_MASK);
    return cmd;
}
