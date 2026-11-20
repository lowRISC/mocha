// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check the ROM window and EXP_DIGEST registers against this build's bootrom image and digest

#include "hal/mmio.h"
#include "hal/mocha.h"
#include "hal/rom_ctrl.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum : size_t {
    rom_size = 0x8000u,
    // Software cannot read the digest at the top of the ROM through the ROM window
    rom_digest_words = 8u,
    rom_readable_size = rom_size - rom_digest_words * sizeof(uint32_t),
};

// From bootrom_image.S
extern const uint8_t rom_ctrl_bootrom_image[];
extern const uint64_t rom_ctrl_bootrom_image_size;

// scramble_image.py emits the digest it stores in the ROM
extern const uint32_t kRomImageHash[rom_digest_words];

// The ROM image is zero-padded up to the digest
static uint8_t rom_expected_byte(size_t offset)
{
    if (offset < rom_ctrl_bootrom_image_size) {
        return rom_ctrl_bootrom_image[offset];
    }
    return 0u;
}

// ROM loads are little-endian
static uint64_t rom_expected_value(size_t offset, size_t width)
{
    uint64_t value = 0u;

    for (size_t i = width; i > 0u; i--) {
        value = (value << 8u) | rom_expected_byte(offset + i - 1u);
    }
    return value;
}

static uint64_t rom_load(rom_t rom, size_t offset, size_t width)
{
    uint8_t *addr = (uint8_t *)rom + offset;

    switch (width) {
    case sizeof(uint64_t):
        return DEV_READ64(addr);
    case sizeof(uint32_t):
        return DEV_READ(addr);
    case sizeof(uint16_t):
        return DEV_READ16(addr);
    default:
        return DEV_READ8(addr);
    }
}

static bool rom_check_load(uart_t console, rom_t rom, size_t offset, size_t width)
{
    uint64_t read = rom_load(rom, offset, width);
    uint64_t expected = rom_expected_value(offset, width);

    if (read != expected) {
        // Use a single digit for the width because uprintf prints integers in full-width hex
        uprintf(console, "ROM offset 0x%lx, %c-byte load: read 0x%lx, expected 0x%lx\n",
                (unsigned long)offset, (char)('0' + width), (unsigned long)read,
                (unsigned long)expected);
        return false;
    }
    return true;
}

// Vary the load width by doubleword to cover every byte lane at each width
static bool rom_sweep_test(uart_t console, rom_t rom)
{
    for (size_t offset = 0u; offset < rom_readable_size; offset += sizeof(uint64_t)) {
        size_t width = sizeof(uint64_t) >> ((offset / sizeof(uint64_t)) % 4u);

        for (size_t lane = 0u; lane < sizeof(uint64_t); lane += width) {
            if (!rom_check_load(console, rom, offset + lane, width)) {
                return false;
            }
        }
    }
    return true;
}

// Use distinct doublewords so a stale value from A fails the read at B
static bool rom_reread_test(uart_t console, rom_t rom)
{
    const size_t a = 0u;
    size_t b = sizeof(uint64_t);

    while (b < rom_readable_size &&
           rom_expected_value(b, sizeof(uint64_t)) == rom_expected_value(a, sizeof(uint64_t))) {
        b += sizeof(uint64_t);
    }
    if (b >= rom_readable_size) {
        uprintf(console, "No ROM doubleword differs from the one at offset 0x%lx\n",
                (unsigned long)a);
        return false;
    }

    return rom_check_load(console, rom, a, sizeof(uint64_t)) &&
           rom_check_load(console, rom, b, sizeof(uint64_t)) &&
           rom_check_load(console, rom, a + sizeof(uint32_t), sizeof(uint32_t)) &&
           rom_check_load(console, rom, a + 1u, sizeof(uint8_t));
}

// EXP_DIGEST_i holds logical ROM word 0x1FF8 + i, which scramble_image.py emits as kRomImageHash[i]
static bool exp_digest_test(uart_t console, rom_ctrl_t rom_ctrl)
{
    for (size_t i = 0u; i < rom_digest_words; i++) {
        uint32_t read = rom_ctrl_exp_digest_read(rom_ctrl, i);

        if (read != kRomImageHash[i]) {
            uprintf(console, "EXP_DIGEST_%c: read 0x%x, expected 0x%x\n", (char)('0' + i), read,
                    kRomImageHash[i]);
            return false;
        }
    }
    return true;
}

bool test_main(uart_t console)
{
    rom_t rom = mocha_system_rom();
    rom_ctrl_t rom_ctrl = mocha_system_rom_ctrl();
    rom_ctrl_fatal_alert_cause cause;

    if (rom_ctrl_bootrom_image_size == 0u || rom_ctrl_bootrom_image_size > rom_readable_size) {
        uprintf(console, "Bootrom image size 0x%lx, expected 0x1 to 0x%lx bytes\n",
                (unsigned long)rom_ctrl_bootrom_image_size, (unsigned long)rom_readable_size);
        return false;
    }

    if (!rom_sweep_test(console, rom) || !rom_reread_test(console, rom) ||
        !exp_digest_test(console, rom_ctrl)) {
        return false;
    }

    cause = rom_ctrl_fatal_alert_cause_read(rom_ctrl);
    if (cause != rom_ctrl_fatal_alert_cause_none) {
        uprintf(console, "FATAL_ALERT_CAUSE: 0x%x\n", (unsigned int)cause);
        return false;
    }
    return true;
}
