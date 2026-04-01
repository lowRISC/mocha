// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mmio.h"
#include "hal/mocha.h"
#include "hal/rom_ctrl.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

#define ADDR_LEN 3
#define DATA_LEN 4

// Check ROM init values
static bool rom_read_test(rom_t rom, uart_t console)
{
    uint32_t data;
    uint32_t address;

    // ROM Address values
    const uint32_t addresses[ADDR_LEN] = { 0x00000000, 0x00004000, 0x00007FF0 };

    // ROM Init values
    const uint32_t expected_data[ADDR_LEN][DATA_LEN] = {
        { 0xDEADBEEF, 0xCAFEBABE, 0x00000001, 0xEEEEEEEE },
        { 0x01234567, 0x10000001, 0x20000002, 0x30000003 },
        { 0xF000000F, 0x0EEEEEE0, 0x0FFFFFF0, 0x01010101 }
    };

    uprintf(console, "\nRead ROM!\n");

    // Reading and comparing
    for (unsigned long address_idx = 0; address_idx < ARRAY_LEN(addresses); address_idx++) {
        for (unsigned long word_idx = 0; word_idx < ARRAY_LEN(expected_data[0]); word_idx++) {
            address = 4 * word_idx + addresses[address_idx];
            data = read_rom(rom, address);
            uprintf(console, "[%lx] | ", (unsigned long)(uintptr_t)(rom + address));
            uprintf(console, "0x%x \n", data);

            if (expected_data[address_idx][word_idx] != data) {
                uprintf(console, "Expected: 0x%x\n", expected_data[address_idx][word_idx]);
                uprintf(console, "ROM Content mismatch Error. Terminating ROM CTRL read test\n");

                return false;
            }
        }
    }

    return true;
}

bool test_main(uart_t console)
{
    rom_t rom = mocha_system_rom();

    return rom_read_test(rom, console);
}
