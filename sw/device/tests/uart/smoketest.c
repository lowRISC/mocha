// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

const static char uart_loopback_test_string[] = "Test String";

static bool loopback_test(uart_t uart)
{
    // Flush the uart
    uart_wait_for(uart, uart_lsr_temt);

    uart_loopback_set(uart, true);
    for (uint32_t idx = 0; idx < sizeof(uart_loopback_test_string); idx++) {
        uart_out(uart, uart_loopback_test_string[idx]);
    }
    // Wait for the transmission to finish
    uart_wait_for(uart, uart_lsr_temt);
    uart_loopback_set(uart, false);

    bool res = true;
    for (uint32_t idx = 0; idx < sizeof(uart_loopback_test_string); idx++) {
        uart_wait_for(uart, uart_lsr_dr);
        char rx = uart_in(uart);
        if (rx != uart_loopback_test_string[idx]) {
            uprintf(uart, "Expected: %c, got: %c\n", rx, uart_loopback_test_string[idx]);
            res = false;
            break;
        }
    }
    return res;
}

bool test_main(uart_t console)
{
    return loopback_test(console);
}
