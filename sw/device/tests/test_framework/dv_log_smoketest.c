// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Smoke test for the SW-DV log interface.

#include "test_framework/dv_log.h"
#include "hal/uart.h"

bool test_main(uart_t console)
{
    (void)console;

    DV_LOG_INFO("SW-DV log smoketest starting...");
    DV_LOG_INFO("a = %d, b = %d, c = %d", 10, 20, 12);
    DV_LOG_INFO("a + b + c = %d", 42);
    DV_LOG_INFO("Smoke test for the SW-DV log interface, completed successfully!");

    return true;
}
