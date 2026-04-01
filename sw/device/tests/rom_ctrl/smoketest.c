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

// Check ROM init values
static bool rom_read_test(rom_t rom, uart_t console)
{
    uint32_t data;
    uint32_t address;
    uint8_t address_length = 3;
    uint8_t data_length = 4;

    // ROM Address values
    const uint32_t expected_addresses[3] = { 0x00000000, 0x00004000, 0x00007FF0 };

    // ROM Init values
    const uint32_t expected_data[3][4] = { { 0xDEADBEEF, 0xCAFEBABE, 0x00000001, 0xEEEEEEEE },
                                           { 0x01234567, 0x10000001, 0x20000002, 0x30000003 },
                                           { 0xF000000F, 0x0EEEEEE0, 0x0FFFFFF0, 0x01010101 } };

    uprintf(console, "\nRead ROM!\n");

    // Reading and comparing
    for (uint8_t address_idx = 0; address_idx < address_length; address_idx++) {
        for (uint8_t word_idx = 0; word_idx < data_length; word_idx++) {
            address = 4 * word_idx + expected_addresses[address_idx];
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

bool test_main()
{
    rom_t rom = mocha_system_rom();
    uart_t console = mocha_system_uart();
    bool read_test_res;

    uart_init(console);

    read_test_res = rom_read_test(rom, console);

    return read_test_res;
}
