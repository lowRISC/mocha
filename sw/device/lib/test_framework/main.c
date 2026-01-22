// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

/* the test's main function. returns whether the test was successful or not */
[[gnu::weak]] bool test_main(uart_t console)
{
    (void)console;
    /* fail by default */
    return false;
}

int main(void)
{
    uart_t console = mocha_system_uart();
    uart_init(console);

    bool result = test_main(console);
    uart_puts(console, "TEST RESULT: ");
    if (result) {
        uart_puts(console, "PASSED");
    } else {
        uart_puts(console, "FAILED");
    }

    // This will kill the simulation if we are running on verilator.
    uart_puts(console, "\nSafe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
