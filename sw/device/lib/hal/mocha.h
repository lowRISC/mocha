// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha System parameters and Peripheral layout.

#pragma once

#include "hal/timer.h"
#include "hal/uart.h"

/* System clock frequency (50 MHz) */
#define SYSCLK_FREQ (50000000)

uart_t mocha_system_uart(void);
timer_t mocha_system_timer(void);
