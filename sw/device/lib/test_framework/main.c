// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

__attribute__((weak)) bool test_main(uart_t console)
{
    uart_puts(console, "Test framework test");
    return true;
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
