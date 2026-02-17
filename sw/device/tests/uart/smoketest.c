// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

const char uart_loopback_test_string[] = "Test String";

static bool loopback_test(uart_t uart)
{
    uart_loopback_set(uart, true, true);
    for (uint32_t idx = 0; idx < sizeof(uart_loopback_test_string); idx++) {
        uart_out(uart, uart_loopback_test_string[idx]);
    }

    bool res = true;
    for (uint32_t idx = 0; idx < sizeof(uart_loopback_test_string); idx++) {
        if (uart_in(uart) != uart_loopback_test_string[idx]) {
            res = false;
            break;
        }
    }
    uart_loopback_set(uart, false, false);
    return res;
}

bool test_main(uart_t console)
{
    return loopback_test(console);
}
