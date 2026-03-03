// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha System parameters and Peripheral layout.

#pragma once

#include "hal/clkmgr.h"
#include "hal/gpio.h"
#include "hal/plic.h"
#include "hal/spi_device.h"
#include "hal/timer.h"
#include "hal/uart.h"

/* System clock frequency (50 MHz) */
#define SYSCLK_FREQ (50000000)

gpio_t mocha_system_gpio(void);
clkmgr_t mocha_system_clkmgr(void);
uart_t mocha_system_uart(void);
timer_t mocha_system_timer(void);
plic_t mocha_system_plic(void);
spi_device_t mocha_system_spi_device(void);
void *mocha_system_dv_test_status(void);
