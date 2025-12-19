// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha_regs.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

const char UartLoopbackTestString[] = "Test String";

static bool loopback_test(uart_t uart)
{
    uart_loopback(uart, true);
    for (uint32_t idx = 0; idx < sizeof(UartLoopbackTestString); idx++) {
        uart_out(uart, UartLoopbackTestString[idx]);
    }

    bool res = true;
    for (uint32_t idx = 0; idx < sizeof(UartLoopbackTestString); idx++) {
        if (uart_in(uart) != UartLoopbackTestString[idx]) {
            res = false;
            break;
        }
    }
    uart_loopback(uart, false);
    return res;
}

bool test_main(uart_t console)
{
    return loopback_test(console);
}
