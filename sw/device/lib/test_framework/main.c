// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

/* magic byte string to terminate the verilator simulation */
static const char magic[] = "\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7";

/* the test's main function. returns whether the test was successful or not */
[[gnu::weak]] bool test_main(uart_t console)
{
    (void)console;
    /* fail by default */
    return false;
}

/* exit the test with a pass or fail */
[[noreturn]] void test_exit(bool success)
{
    uart_t console = mocha_system_uart();
    uart_puts(console, "TEST RESULT: ");
    if (success) {
        uart_puts(console, "PASSED");
    } else {
        uart_puts(console, "FAILED");
    }
    uart_putchar(console, '\n');
    uart_puts(console, "Safe to exit simulator.");
    uart_puts(console, magic);

    /* magic string should have terminated the verilator simulation */
    while (true) {
    }
}

[[noreturn]] void main(void)
{
    uart_t console = mocha_system_uart();
    uart_init(console);

    bool result = test_main(console);

    test_exit(result);
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
