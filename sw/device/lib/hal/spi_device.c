// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/spi_device.h"
#include "builtin.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

enum : size_t {
    spi_device_sfdp_size_sfdp_header = 2u,
    spi_device_sfdp_size_bfpt_header = 2u,
    spi_device_sfdp_size_bfpt = 23u,
};

enum : size_t {
    spi_device_sfdp_offset_sfdp_header = 0u,
    spi_device_sfdp_offset_bfpt_header =
        spi_device_sfdp_offset_sfdp_header + spi_device_sfdp_size_sfdp_header,
    spi_device_sfdp_offset_bfpt =
        spi_device_sfdp_offset_bfpt_header + spi_device_sfdp_size_bfpt_header,
};

/* SFDP signature */
enum : uint32_t {
    sfdp_signature = 0x50444653u,
};

enum : uint8_t {
    sfdp_major = 0x01u,
    sfdp_minor = 0x0au,
};

/* access protocol for SFDP: 3-byte addressing, 8 wait states (dummy cycles) (JESD216F 6.2.3) */
enum : uint8_t {
    spi_device_sfdp_access_protocol = 0xffu,
};

/* BFPT header */
enum : uint8_t {
    bfpt_major = 0x01u,
    bfpt_minor = 0x07u,
};

enum : uint32_t {
    spi_device_log2_density_bytes = 20u,
    spi_device_log2_density_bits = spi_device_log2_density_bytes + 3u,
};

static const uint32_t spi_device_lowrisc_flash_sfdp[] = {
    /* SFDP signature that indicates the presence of a SFDP table (JESD216F 6.2.1) */
    [spi_device_sfdp_offset_sfdp_header] = sfdp_signature,

    /* [ 7: 0]: SFDP minor revision number (JESD216F 6.2.2)
     * [15: 8]: SFDP major revision number (JESD216F 6.2.2)
     * [23:16]: Number of parameter headers, zero-based (JESD216F 6.2.2) = 0x0
     * [31:24]: SFDP access protocol (JESD216F 6.2.3) */
    [spi_device_sfdp_offset_sfdp_header + 1u] =
        (((uint32_t)spi_device_sfdp_access_protocol) << 24) | (0x00 << 16) |
        (((uint32_t)sfdp_major) << 8) | ((uint32_t)(sfdp_minor)),

    /* Basic Flash Parameters Table (BFPT) parameter header */
    /* BFPT parameter header word 1:
     * [ 7: 0]: LSB of the parameter ID that indicates parameter table ownership and type
     *          (JESD216F 6.3.1, 6.3.3) = 0x7
     * [15: 8]: Parameter table minor revision number (JESD216F 6.3.1)
     * [23:16]: Parameter table major revision number (JESD216F 6.3.1)
     * [31:24]: Length of the parameter table in words, one-based (JESD216F 6.3.1) = 23 */
    [spi_device_sfdp_offset_bfpt_header] =
        (spi_device_sfdp_size_bfpt << 24) | (((uint32_t)bfpt_major) << 16) |
        (((uint32_t)bfpt_minor) << 8),

    /* BFPT parameter header word 2:
     * [23: 0]: Word-aligned byte offset of the corresponding parameter table from the start of
     *          the SFDP table (JESD216F 6.3.2)
     * [31:24]: MSB of the parameter ID that indicates parameter table ownership and type
     *          (JESD216F 6.3.2, 6.3.3) */
    [spi_device_sfdp_offset_bfpt_header + 1u] = (0xffu << 24) | (0x04u),

    /* Note: Words below are numbered starting from 1 to match JESD216F. Some fields
     * that are not supported by OpenTitan are merged for the sake of conciseness.
     * Reserved fields are set to all 1s, unless otherwise specified. */

    /* BFPT word 1:
     * [31:23]: Unused (all 1s)
     * [22:19]: (1S-1S-4S) (1S-4S-4S) (1S-2S-2S) DTR Clock = 0x0 (not supported)
     * [18:17]: Address bytes = 0x0 (3-byte only addressing)
     * [16:16]: (1S-1S-2S) = 0x0 (not supported)
     * [15: 8]: 4 KiB erase instruction opcode = 0x20
     * [ 7: 5]: Unused (all 1s)
     * [ 4: 4]: Write enable instruction opcode = 0x1 (use 0x06 for WREN)
     * [ 3: 3]: Volatile block protect bits = 0x1 (solely volatile)
     * [ 2: 2]: Write granularity = 0x1 (buffer >= 64 B)
     * [ 1: 0]: Block/sector erase sizes = 0x1 (uniform 4 KiB erase) */
    [spi_device_sfdp_offset_bfpt] =
        (0x1ffu << 23) | (((uint32_t)spi_device_opcode_sector_erase) << 8) | (0b11111101u),

    /* BFPT word 2:
     * [31:31]: Density greater than 2 Gib = 0x0 (false)
     * [30: 0]: Flash memory density in bits, zero-based (0x7fffff) */
    [spi_device_sfdp_offset_bfpt + 1u] = (1u << spi_device_log2_density_bits) - 1u,

    /* BFPT word 3:
     * [31: 0]: Fast read (1S-4S-4S) (1S-1S-4S) = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 2u] = 0u,

    /* BFPT word 4:
     * [31: 0]: Fast read (1S-1S-2S) (1S-2S-2S) = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 3u] = 0u,

    /* BFPT word 5:
     * [31: 5]: Reserved
     * [ 4: 4]: Fast read (4S-4S-4S) support = 0x0 (not supported)
     * [ 3: 1]: Reserved
     * [ 0: 0]: Fast read (2S-2S-2S) support = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 4u] = UINT32_MAX & ~(0b1u << 4) & ~(0b1u),

    /* BFPT word 6:
     * [31:16]: Fast read (2S-2S-2S) (not supported, 0x0)
     * [15: 0]: Reserved */
    [spi_device_sfdp_offset_bfpt + 5u] = 0x0000ffffu,

    /* BFPT word 7:
     * [31:16]: Fast read (4S-4S-4S) = 0x0 (not supported)
     * [15: 0]: Reserved */
    [spi_device_sfdp_offset_bfpt + 6u] = 0x0000ffffu,

    /* BFPT word 8:
     * [31:16]: Erase type 2 instruction and size = 0x0 (not supported)
     * [15: 8]: Erase type 1 instruction opcode = 0x20
     * [ 7: 0]: log2 of Erase type 1 size = 0x0c (4 KiB) */
    [spi_device_sfdp_offset_bfpt + 7u] =
        (((uint32_t)spi_device_opcode_sector_erase) << 8) | (0x0cu),

    /* BFPT word 9:
     * [31: 0]: Erase type 4 and 3 = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 8u] = 0u,

    /* BFPT word 10:
     * [31:11]: Erase 4,3,2 typical time = 0x0 (not supported)
     * [10: 9]: Erase type 1 time unit = 0x1 (16 ms)
     * [ 8: 4]: Erase type 1 time count, zero-based = 0x8
     *          formula: (count + 1) * unit
     *          (8 + 1) * 16 ms = 144 ms
     * [ 3: 0]: Max erase time multiplier, zero-based = 0x6
     *          formula: 2 * (multiplier + 1) * erase_time */
    [spi_device_sfdp_offset_bfpt + 9u] = (0x1u << 9) | (0x8u << 4) | (0x6u),

    /* BFPT word 11:
     * [31:31]: Reserved
     * [30:29]: Chip erase time units = 0x0 (16 ms)
     * [28:24]: Chip erase time count, zero-based = 0xb
     *          formula: (count + 1) * unit
     *          (11 + 1) * 16 ms = 192 ms
     * [23:23]: Additional byte program time units = 0x1 (8 us)
     * [22:19]: Additional byte program time count, zero-based = 0x5
     *          formula: (count + 1) * unit
     *          (5 + 1) * 8 us = 48 us
     * [18:18]: First byte program time unit = 0x1 (8 us)
     * [17:14]: First byte program time count, zero-based = 0x5
     *          formula: (count + 1) * unit
     *          (5 + 1) * 8 us = 48 us
     * [13:13]: Page program time unit = 0x1 (64 us)
     * [12: 8]: Page program time count, zero-based = 0x0b
     *          formula: (count + 1) * unit
     *          (11 + 1) * 64 us = 768 us
     * [ 7: 4]: log2 of page size = 0x8 (512-byte pages)
     * [ 3: 0]: Max program time multiplier, zero-based = 0x0
     *          formula: 2 * (multiplier + 1) * program_time */
    [spi_device_sfdp_offset_bfpt + 10u] =
        (0b1u << 31) | (0xbu << 24) | (0b1u << 23) | (0x5u << 19) | (0b1u << 18) | (0x5u << 14) |
        (0b1u << 13) | (0xbu << 8) | (0x8u << 4),

    /* BFPT word 12:
     * [31:31]: Suspend/Resume supported = 0x1 (not supported)
     * [30: 9]: Suspend/Resume latencies for erase & program = 0x1 (not supported)
     * [ 8: 8]: Reserved
     * [ 7: 0]: Prohibited ops during suspend = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 11u] = (0b1u << 31) | (0b1u << 8),

    /* BFPT word 13:
     * [31: 0]: Erase/program suspend/resume instructions = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 12u] = 0u,

    /* BFPT word 14:
     * [31:31]: Deep powerdown support = 0x1 (not supported)
     * [30: 8]: Deep powerdown instructions and delay = 0x0 (not supported)
     * [ 7: 2]: Busy polling = 0x1 (poll on bit 0 using 0x05 opcode)
     * [ 1: 0]: Reserved */
    [spi_device_sfdp_offset_bfpt + 13u] = (0b1u << 31) | (0x1u << 2) | (0b11),

    /* BFPT word 15:
     * [31:24]: Reserved
     * [23: 0]: Hold, QE, (4S-4S-4S), 0-4-4 = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 14u] = (0xffu << 24),

    /* BFPT word 16:
     * [31:14]: 4-Byte addressing = 0x0 (not supported)
     * [13: 8]: Soft-reset = 0x10 (0x66/0x99 sequence)
     * [ 7: 7]: Reserved
     * [ 6: 0]: Status register = 0x0 (read-only) */
    [spi_device_sfdp_offset_bfpt + 15u] = (0x10u << 8) | (0b1u << 7),

    /* BFPT word 17:
     * [31: 0]: Fast read (1S-8S-8S) (1S-1S-8S) = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 16u] = 0u,

    /* BFPT word 18:
     * Reserved fields of this word should be 0 (JESD216F 6.4.21)
     * [31, 0]: Data strobe, SPI protocol reset, etc. = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 17u] = 0u,

    /* BFPT word 19:
     * Reserved fields of this word should be 0 (JESD216F 6.4.22)
     * [31, 0]: Octable enable, (8D-8D-8D), 0-8-8 mode = 0x0 (not suported) */
    [spi_device_sfdp_offset_bfpt + 18u] = 0u,

    /* BFPT word 20:
     * [31, 0]: Max (8S-8S-8S) (4D-4D-4D) (4S-4S-4S) speed = all 1s (not supported) */
    [spi_device_sfdp_offset_bfpt + 19u] = UINT32_MAX,

    /* BFPT word 21:
     * Reserved fields of this word should be 0 (JESD216F 6.4.24)
     * [31, 0]: Fast read support for various modes = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 20u] = 0u,

    /* BFPT word 22:
     * [31, 0]: Fast read (1S-1D-1D) (1S-2D-2D) = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 21u] = 0u,

    /* BFPT word 23:
     * [31, 0]: Fast read (1S-4D-4D) (4S-2D-2D) = 0x0 (not supported) */
    [spi_device_sfdp_offset_bfpt + 22u] = 0u,
};

_Static_assert(ARRAY_LEN(spi_device_lowrisc_flash_sfdp) ==
                   spi_device_sfdp_size_sfdp_header + spi_device_sfdp_size_bfpt_header +
                       spi_device_sfdp_size_bfpt,
               "SFDP data unexpected size");

_Static_assert(ARRAY_LEN(spi_device_lowrisc_flash_sfdp) <= spi_device_egress_buffer_size_sfdp,
               "SFDP data too big to fit in buffer");

static const spi_device_jedec_cc lowrisc_jedec_cc = {
    /* lowRISC's JEDEC ID consists of 12 0x7F continuation codes ... */
    .cc = 0x7fu,
    /* Workaround for openFPGAloader only reading one byte for JEDEC manufacturer ID */
    .num_cc = 0u,
};

static const spi_device_jedec_id lowrisc_jedec_id = {
    /* ... followed by 0xEF */
    .mf = 0xefu,
    /* JEDEC device ID:
     * [15: 8]: log2 of flash size in bytes
     * [ 7: 4]: Chip generation = 0x0
     * [ 3: 3]: Bootstrap bit = 0x1
     * [ 2: 0]: Chip revision = 0x0 */
    .id = (((uint16_t)spi_device_log2_density_bytes) << 8u) | (0b1u << 3),
};

void spi_device_init(spi_device_t spi_device)
{
    spi_device_jedec_cc_set(spi_device, lowrisc_jedec_cc);
    spi_device_jedec_id_set(spi_device, lowrisc_jedec_id);

    /* fill SFDP with all 1s, then write the flash SFDP data into it */
    for (size_t i = 0; i < spi_device_egress_buffer_size_sfdp; i++) {
        VOLATILE_WRITE(spi_device->egress_buffer[spi_device_egress_buffer_offset_sfdp + i],
                       UINT32_MAX);
    }
    for (size_t i = 0; i < ARRAY_LEN(spi_device_lowrisc_flash_sfdp); i++) {
        VOLATILE_WRITE(spi_device->egress_buffer[spi_device_egress_buffer_offset_sfdp + i],
                       spi_device_lowrisc_flash_sfdp[i]);
    }

    spi_device_flash_status status = { 0u };
    spi_device_flash_status_set(spi_device, status);

    /* Configure command slots */
    /* Slot 0: read status */
    spi_device_cmd_info command_slot_0 = {
        .opcode = spi_device_opcode_read_status,
        .addr_mode = spi_device_addr_mode_disabled,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_slot_0, 0u);

    /* Slot 3: read JEDEC */
    spi_device_cmd_info command_slot_3 = {
        .opcode = spi_device_opcode_read_jedec,
        .addr_mode = spi_device_addr_mode_disabled,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_slot_3, 3u);

    /* Slot 4: read SFDP */
    spi_device_cmd_info command_slot_4 = {
        .opcode = spi_device_opcode_read_sfdp,
        .addr_mode = spi_device_addr_mode_3b,
        .dummy_en = true,
        .dummy_size = 7u,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_slot_4, 4u);

    /* Slot 5: read */
    spi_device_cmd_info command_slot_5 = {
        .opcode = spi_device_opcode_read,
        .addr_mode = spi_device_addr_mode_cfg,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_slot_5, 5u);

    /* Slot 11: chip erase */
    spi_device_cmd_info command_slot_11 = {
        .opcode = spi_device_opcode_chip_erase,
        .addr_mode = spi_device_addr_mode_disabled,
        .upload = true,
        .busy = true,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_slot_11, 11u);

    /* Slot 12: sector erase */
    spi_device_cmd_info command_slot_12 = {
        .opcode = spi_device_opcode_sector_erase,
        .addr_mode = spi_device_addr_mode_cfg,
        .upload = true,
        .busy = true,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_slot_12, 12u);

    /* Slot 13: page program */
    spi_device_cmd_info command_info_13 = {
        .opcode = spi_device_opcode_page_program,
        .addr_mode = spi_device_addr_mode_cfg,
        .upload = true,
        .busy = true,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_info_13, 13u);

    /* Slot 14: reset */
    spi_device_cmd_info command_info_14 = {
        .opcode = spi_device_opcode_reset,
        .addr_mode = spi_device_addr_mode_disabled,
        .upload = true,
        .busy = true,
        .valid = true,
    };
    spi_device_cmd_info_set(spi_device, command_info_14, 14u);

    /* enable write enable and write disable commands */
    spi_device_cmd_info_wren_set(spi_device, spi_device_opcode_wren, true);
    spi_device_cmd_info_wrdi_set(spi_device, spi_device_opcode_wrdi, true);

    /* disable 4b address mode */
    spi_device_4b_addr_mode_enable_set_unchecked(spi_device, false);
}

void spi_device_flash_mode_set(spi_device_t spi_device, enum spi_device_flash_mode mode)
{
    spi_device_control control = VOLATILE_READ(spi_device->control);
    control.mode = mode;
    VOLATILE_WRITE(spi_device->control, control);
}

spi_device_intr spi_device_interrupt_enable_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->intr_enable);
}

void spi_device_interrupt_enable_set(spi_device_t spi_device, spi_device_intr intrs)
{
    VOLATILE_WRITE(spi_device->intr_enable, intrs);
}

void spi_device_interrupt_enable(spi_device_t spi_device, spi_device_intr intrs)
{
    spi_device_intr enable = VOLATILE_READ(spi_device->intr_enable);
    VOLATILE_WRITE(spi_device->intr_enable, enable | intrs);
}

void spi_device_interrupt_disable(spi_device_t spi_device, spi_device_intr intrs)
{
    spi_device_intr enable = VOLATILE_READ(spi_device->intr_enable);
    VOLATILE_WRITE(spi_device->intr_enable, enable & ~intrs);
}

void spi_device_interrupt_disable_all(spi_device_t spi_device)
{
    VOLATILE_WRITE(spi_device->intr_enable, 0u);
}

void spi_device_interrupt_force(spi_device_t spi_device, spi_device_intr intrs)
{
    VOLATILE_WRITE(spi_device->intr_test, intrs);
}

void spi_device_interrupt_clear(spi_device_t spi_device, spi_device_intr intrs)
{
    VOLATILE_WRITE(spi_device->intr_state, intrs);
}

bool spi_device_interrupt_all_pending(spi_device_t spi_device, uint32_t intrs)
{
    return (VOLATILE_READ(spi_device->intr_state) & intrs) == intrs;
}

bool spi_device_interrupt_any_pending(spi_device_t spi_device, uint32_t intrs)
{
    return (VOLATILE_READ(spi_device->intr_state) & intrs) != 0u;
}

spi_device_flash_status spi_device_flash_status_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->flash_status);
}

void spi_device_flash_status_set(spi_device_t spi_device, spi_device_flash_status status)
{
    VOLATILE_WRITE(spi_device->flash_status, status);
}

void spi_device_flash_status_busy_set(spi_device_t spi_device, bool busy)
{
    spi_device_flash_status status = VOLATILE_READ(spi_device->flash_status);
    status.busy = busy;
    VOLATILE_WRITE(spi_device->flash_status, status);
}

void spi_device_flash_status_wel_set(spi_device_t spi_device, bool wel)
{
    spi_device_flash_status status = VOLATILE_READ(spi_device->flash_status);
    status.wel = wel;
    VOLATILE_WRITE(spi_device->flash_status, status);
}

bool spi_device_4b_addr_mode_enable_get(spi_device_t spi_device)
{
    spi_device_addr_mode mode = VOLATILE_READ(spi_device->addr_mode);
    return mode.addr_4b_en;
}

void spi_device_4b_addr_mode_enable_set(spi_device_t spi_device, bool enable)
{
    spi_device_4b_addr_mode_enable_set_unchecked(spi_device, enable);
    /* poll the pending bit until the update is committed */
    spi_device_addr_mode mode;
    do {
        mode = VOLATILE_READ(spi_device->addr_mode);
    } while (mode.pending == true);
}

void spi_device_4b_addr_mode_enable_set_unchecked(spi_device_t spi_device, bool enable)
{
    spi_device_addr_mode mode = { .addr_4b_en = enable };
    VOLATILE_WRITE(spi_device->addr_mode, mode);
}

spi_device_cmd_info spi_device_cmd_info_get(spi_device_t spi_device, size_t index)
{
    if (index >= ARRAY_LEN(spi_device->cmd_info)) {
        spi_device_cmd_info invalid = { 0u };
        return invalid;
    }
    return VOLATILE_READ(spi_device->cmd_info[index]);
}

void spi_device_cmd_info_set(spi_device_t spi_device, spi_device_cmd_info cmd_info, size_t index)
{
    if (index >= ARRAY_LEN(spi_device->cmd_info)) {
        return;
    }
    VOLATILE_WRITE(spi_device->cmd_info[index], cmd_info);
}

spi_device_cmd_info_wren spi_device_cmd_info_wren_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->cmd_info_wren);
}

void spi_device_cmd_info_wren_set(spi_device_t spi_device, uint8_t opcode, bool valid)
{
    spi_device_cmd_info_wren wren = {
        .opcode = opcode,
        .valid = valid,
    };
    VOLATILE_WRITE(spi_device->cmd_info_wren, wren);
}

spi_device_cmd_info_wrdi spi_device_cmd_info_wrdi_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->cmd_info_wrdi);
}

void spi_device_cmd_info_wrdi_set(spi_device_t spi_device, uint8_t opcode, bool valid)
{
    spi_device_cmd_info_wrdi wrdi = {
        .opcode = opcode,
        .valid = valid,
    };
    VOLATILE_WRITE(spi_device->cmd_info_wrdi, wrdi);
}

uint32_t spi_device_cmd_filter_get(spi_device_t spi_device, size_t index)
{
    if (index >= ARRAY_LEN(spi_device->cmd_filter)) {
        return 0u;
    }
    return VOLATILE_READ(spi_device->cmd_filter[index]);
}

void spi_device_cmd_filter_enable_all(spi_device_t spi_device)
{
    for (size_t index = 0u; index < ARRAY_LEN(spi_device->cmd_filter); index++) {
        VOLATILE_WRITE(spi_device->cmd_filter[index], UINT32_MAX);
    }
}

void spi_device_cmd_filter_enable_set(spi_device_t spi_device, size_t index, uint32_t filter)
{
    if (index >= ARRAY_LEN(spi_device->cmd_filter)) {
        return;
    }
    VOLATILE_WRITE(spi_device->cmd_filter[index], filter);
}

void spi_device_cmd_filter_enable(spi_device_t spi_device, size_t index, uint32_t filter)
{
    if (index >= ARRAY_LEN(spi_device->cmd_filter)) {
        return;
    }
    uint32_t cmd_filter = VOLATILE_READ(spi_device->cmd_filter[index]);
    VOLATILE_WRITE(spi_device->cmd_filter[index], cmd_filter | filter);
}

void spi_device_cmd_filter_disable(spi_device_t spi_device, size_t index, uint32_t filter)
{
    if (index >= ARRAY_LEN(spi_device->cmd_filter)) {
        return;
    }
    uint32_t cmd_filter = VOLATILE_READ(spi_device->cmd_filter[index]);
    VOLATILE_WRITE(spi_device->cmd_filter[index], cmd_filter & ~filter);
}

void spi_device_cmd_filter_disable_all(spi_device_t spi_device)
{
    for (size_t index = 0u; index < ARRAY_LEN(spi_device->cmd_filter); index++) {
        VOLATILE_WRITE(spi_device->cmd_filter[index], 0u);
    }
}

spi_device_jedec_cc spi_device_jedec_cc_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->jedec_cc);
}

void spi_device_jedec_cc_set(spi_device_t spi_device, spi_device_jedec_cc jedec_cc)
{
    VOLATILE_WRITE(spi_device->jedec_cc, jedec_cc);
}

spi_device_jedec_id spi_device_jedec_id_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->jedec_id);
}

void spi_device_jedec_id_set(spi_device_t spi_device, spi_device_jedec_id jedec_id)
{
    VOLATILE_WRITE(spi_device->jedec_id, jedec_id);
}

spi_device_upload_status spi_device_upload_status_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->upload_status);
}

spi_device_upload_status2 spi_device_upload_status2_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->upload_status2);
}

spi_device_upload_cmdfifo spi_device_upload_cmdfifo_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->upload_cmdfifo);
}

uint32_t spi_device_upload_addrfifo_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->upload_addrfifo);
}

uint32_t spi_device_mailbox_addr_get(spi_device_t spi_device)
{
    return VOLATILE_READ(spi_device->mailbox_addr);
}

void spi_device_mailbox_addr_set(spi_device_t spi_device, uint32_t mailbox_addr)
{
    VOLATILE_WRITE(spi_device->mailbox_addr, mailbox_addr);
}

enum spi_device_status spi_device_software_command_get_non_blocking(
    spi_device_t spi_device, spi_device_software_command *command)
{
    /* busy poll for a software-handled command */
    if (!spi_device_interrupt_all_pending(spi_device, spi_device_intr_upload_cmdfifo_not_empty)) {
        return spi_device_status_empty;
    }

    /* clear the interrupt */
    spi_device_interrupt_clear(spi_device, spi_device_intr_upload_cmdfifo_not_empty);

    /* check for payload overflow */
    if (spi_device_interrupt_all_pending(spi_device, spi_device_intr_upload_payload_overflow)) {
        spi_device_interrupt_clear(spi_device, spi_device_intr_upload_payload_overflow);
        return spi_device_status_overflow;
    }

    /* get the command opcode, address, and payload size */
    command->opcode = spi_device_upload_cmdfifo_get(spi_device).data;

    if (spi_device_upload_status_get(spi_device).addrfifo_notempty) {
        command->has_address = true;
        command->address = spi_device_upload_addrfifo_get(spi_device);
    } else {
        /* no address */
        command->has_address = false;
        command->address = 0u;
    }
    command->payload_byte_count = spi_device_upload_status2_get(spi_device).payload_depth;

    return spi_device_status_ready;
}

enum spi_device_status
spi_device_software_command_get(spi_device_t spi_device, spi_device_software_command *command)
{
    /* busy poll for a software-handled command */
    while (
        !spi_device_interrupt_all_pending(spi_device, spi_device_intr_upload_cmdfifo_not_empty)) {
    }

    return spi_device_software_command_get_non_blocking(spi_device, command);
}

void spi_device_flash_payload_buffer_copy_bytes(spi_device_t spi_device, size_t num_bytes,
                                                uint32_t *dest)
{
    size_t round_up_bytes = (num_bytes + 0b11u) & (~0b11u);
    size_t num_words = round_up_bytes / sizeof(uint32_t);
    /* limit to length of payload fifo */
    num_words = num_words > spi_device_ingress_buffer_size_payload_fifo ?
                    spi_device_ingress_buffer_size_payload_fifo :
                    num_words;
    for (size_t i = 0; i < num_words; i++) {
        dest[i] = VOLATILE_READ(
            spi_device->ingress_buffer[spi_device_ingress_buffer_offset_payload_fifo + i]);
    }
}

bool spi_device_flash_payload_buffer_read_word(spi_device_t spi_device, size_t word_index,
                                               uint32_t *word)
{
    if (word_index >= spi_device_ingress_buffer_size_payload_fifo) {
        return false;
    }
    *word = VOLATILE_READ(
        spi_device->ingress_buffer[spi_device_ingress_buffer_offset_payload_fifo + word_index]);
    return true;
}

bool spi_device_flash_payload_buffer_read_byte(spi_device_t spi_device, size_t byte_index,
                                               uint8_t *byte)
{
    size_t word_index = byte_index >> 4u;
    uint32_t word;
    if (!spi_device_flash_payload_buffer_read_word(spi_device, word_index, &word)) {
        return false;
    }

    *byte = (uint8_t)(word >> ((byte_index % 4u) * 8u));
    return true;
}

bool spi_device_flash_read_buffer_write_word(spi_device_t spi_device, size_t word_index,
                                             uint32_t word)
{
    if (word_index >= spi_device_egress_buffer_size_read) {
        return false;
    }

    VOLATILE_WRITE(spi_device->egress_buffer[spi_device_egress_buffer_offset_read + word_index],
                   word);
    return true;
}

bool spi_device_flash_read_buffer_write_byte(spi_device_t spi_device, size_t byte_index,
                                             uint8_t byte)
{
    size_t word_index = byte_index >> 4u;
    if (word_index >= spi_device_egress_buffer_size_read) {
        return false;
    }

    uint32_t word =
        VOLATILE_READ(spi_device->egress_buffer[spi_device_egress_buffer_offset_read + word_index]);
    size_t shift = (byte_index % 4u) * 8u;
    word &= ~(0xffu << shift);
    word |= ((uint32_t)byte) << shift;
    VOLATILE_WRITE(spi_device->egress_buffer[spi_device_egress_buffer_offset_read + word_index],
                   word);
    return true;
}
