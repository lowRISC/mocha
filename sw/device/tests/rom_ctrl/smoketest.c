// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/rom_ctrl.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

// Check that we can write and read some GPIO registers
static bool rom_read_test(rom_t rom, uart_t console)
{
    uint32_t res;
    uint8_t num_of_words_to_read = 16;

    for (uint8_t word_idx = 0; word_idx < num_of_words_to_read; word_idx++) {
       res = read_rom(rom, word_idx);
       uprintf(console, "Res[%d]:", word_idx);
       uprintf(console, "0x%0x\n", res);
    }


    return true;
}

bool test_main()
{
    rom_t rom = mocha_system_rom();
    uart_t console = mocha_system_uart();

    uart_init(console);
    uprintf(console, "\nRead ROM!\n");

    return rom_read_test(rom, console);
}
