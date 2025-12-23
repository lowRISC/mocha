// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha_regs.h"
#include "hal/uart.h"
#include <stdint.h>

int main(void)
{
    uart_t uart = (uart_t)UART_BASE;
    uart_init(uart);

    uart_puts(uart, "Hello CHERI Mocha!\n");

    // Trying out simulation exit.
    uart_puts(uart, "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");
    uart_puts(uart, "This should not be printed in simulation.\r\n");

    while (1) {
    }

    return 0;
}
