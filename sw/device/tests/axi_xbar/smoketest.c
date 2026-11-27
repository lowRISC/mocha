// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reach the SRAM, the ROM, the mailbox and the SW-DV window through the AXI crossbar: write and
// read back the SRAM and the mailbox registers, read the ROM against this build's bootrom image
// and read the hardware ID of the SW-DV window

#include "hal/dv.h"
#include "hal/mailbox.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum : size_t {
    sram_size = 0x20000u,
    rom_size = 0x8000u,
    // Software cannot read the digest at the top of the ROM through the ROM window
    rom_readable_size = rom_size - 8u * sizeof(uint32_t),
    num_mailbox_regs = 3u,
};

// From rom_ctrl/bootrom_image.S
extern const uint8_t rom_ctrl_bootrom_image[];
extern const uint64_t rom_ctrl_bootrom_image_size;

// Write a different value at each end of the SRAM window before reading either back, so a read
// that returns the other value fails. A second pass writes the complements, so a write that does
// not land fails whatever the SRAM held before the test.
static bool sram_test(uart_t console, void *sram)
{
    const size_t offsets[] = { 0u, sram_size - sizeof(uint64_t) };
    const uint64_t values[] = { 0x0123456789abcdefull, 0xfedcba9876543210ull };
    bool passed = true;

    for (size_t pass = 0u; pass < 2u; pass++) {
        const uint64_t flip = pass == 0u ? 0u : ~0ull;

        for (size_t i = 0u; i < 2u; i++) {
            DEV_WRITE64((uint8_t *)sram + offsets[i], values[i] ^ flip);
        }
        for (size_t i = 0u; i < 2u; i++) {
            uint64_t read = DEV_READ64((uint8_t *)sram + offsets[i]);
            uint64_t expected = values[i] ^ flip;

            if (read != expected) {
                uprintf(console, "SRAM offset 0x%lx: read 0x%lx, expected 0x%lx\n",
                        (unsigned long)offsets[i], (unsigned long)read, (unsigned long)expected);
                passed = false;
            }
        }
    }
    return passed;
}

// The ROM image is zero-padded up to the digest. ROM loads are little-endian.
static uint64_t rom_expected_dword(size_t offset)
{
    uint64_t value = 0u;

    for (size_t i = sizeof(uint64_t); i > 0u; i--) {
        size_t byte = offset + i - 1u;

        value = (value << 8u) |
                (byte < rom_ctrl_bootrom_image_size ? rom_ctrl_bootrom_image[byte] : 0u);
    }
    return value;
}

// Read the first doubleword of the ROM window and the last one below the digest
static bool rom_test(uart_t console, rom_t rom)
{
    const size_t offsets[] = { 0u, rom_readable_size - sizeof(uint64_t) };
    bool passed = true;

    if (rom_ctrl_bootrom_image_size == 0u || rom_ctrl_bootrom_image_size > rom_readable_size) {
        uprintf(console, "Bootrom image size 0x%lx, expected 0x1 to 0x%lx bytes\n",
                (unsigned long)rom_ctrl_bootrom_image_size, (unsigned long)rom_readable_size);
        return false;
    }

    for (size_t i = 0u; i < 2u; i++) {
        uint64_t read = DEV_READ64((uint8_t *)rom + offsets[i]);
        uint64_t expected = rom_expected_dword(offsets[i]);

        if (read != expected) {
            uprintf(console, "ROM offset 0x%lx: read 0x%lx, expected 0x%lx\n",
                    (unsigned long)offsets[i], (unsigned long)read, (unsigned long)expected);
            passed = false;
        }
    }
    return passed;
}

// WIRQT and RIRQT hold $clog2(MAILBOX_FIFO_DEPTH) bits
_Static_assert(MAILBOX_FIFO_DEPTH > 2u && MAILBOX_FIFO_DEPTH <= 4u,
               "mailbox_threshold_mask assumes two threshold bits");
static const uint64_t mailbox_threshold_mask = 0x3u;

// Write two sets of values to the writable mailbox registers, then their reset values, reading
// each set back. The second WIRQT write is the FIFO depth, which the mailbox clamps to the depth
// minus one. A memory would return the value written, so that read back tells the mailbox from a
// memory reached through the same addresses. Only the defined fields are compared, since the
// specification gives no read value for the reserved bits above them.
static bool mailbox_test(uart_t console, mailbox_t mailbox)
{
    const size_t regs[num_mailbox_regs] = { MAILBOX_WIRQT, MAILBOX_RIRQT, MAILBOX_IRQEN };
    const uint64_t masks[num_mailbox_regs] = {
        mailbox_threshold_mask,
        mailbox_threshold_mask,
        MAILBOX_IRQ_WTIRQ_MASK | MAILBOX_IRQ_RTIRQ_MASK | MAILBOX_IRQ_EIRQ_MASK,
    };
    const uint64_t writes[][num_mailbox_regs] = {
        { 1u, 2u, MAILBOX_IRQ_WTIRQ_MASK | MAILBOX_IRQ_EIRQ_MASK },
        { MAILBOX_FIFO_DEPTH, 1u, MAILBOX_IRQ_RTIRQ_MASK },
        { 0u, 0u, 0u },
    };
    const uint64_t expected[][num_mailbox_regs] = {
        { 1u, 2u, MAILBOX_IRQ_WTIRQ_MASK | MAILBOX_IRQ_EIRQ_MASK },
        { MAILBOX_FIFO_DEPTH - 1u, 1u, MAILBOX_IRQ_RTIRQ_MASK },
        { 0u, 0u, 0u },
    };
    bool passed = true;

    for (size_t set = 0u; set < sizeof(writes) / sizeof(writes[0]); set++) {
        for (size_t i = 0u; i < num_mailbox_regs; i++) {
            DEV_WRITE64((uint8_t *)mailbox + regs[i], writes[set][i]);
        }
        for (size_t i = 0u; i < num_mailbox_regs; i++) {
            uint64_t read = DEV_READ64((uint8_t *)mailbox + regs[i]) & masks[i];

            if (read != expected[set][i]) {
                uprintf(console, "Mailbox offset 0x%lx: read 0x%lx, expected 0x%lx\n",
                        (unsigned long)regs[i], (unsigned long)read,
                        (unsigned long)expected[set][i]);
                passed = false;
            }
        }
    }
    return passed;
}

// HW_ID is read only and names the platform, so it must be one of the known IDs
static bool dv_window_test(uart_t console, dv_window_t dv_window)
{
    uint32_t hw_id = DEV_READ(&dv_window->hw_id);

    switch (hw_id) {
    case dv_hwid_fpga_genesys2:
    case dv_hwid_sim_verilator:
    case dv_hwid_sim_uvm:
        return true;
    default:
        uprintf(console, "SW-DV window HW_ID: read 0x%x, not a known platform\n", hw_id);
        return false;
    }
}

bool test_main(uart_t console)
{
    bool passed = true;

    // Run the later checks after a mismatch too. A bus error still ends the test in the exception
    // handler.
    passed &= sram_test(console, mocha_system_sram());
    passed &= rom_test(console, mocha_system_rom());
    passed &= mailbox_test(console, mocha_system_mailbox());
    passed &= dv_window_test(console, mocha_system_dv_window());
    return passed;
}
