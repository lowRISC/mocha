// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha System parameters and Peripheral layout.

#pragma once

#include "hal/clkmgr.h"
#include "hal/gpio.h"
#include "hal/i2c.h"
#include "hal/mailbox.h"
#include "hal/plic.h"
#include "hal/rstmgr.h"
#include "hal/spi_device.h"
#include "hal/timer.h"
#include "hal/uart.h"

/* System clock period in nanoseconds (20 ns) */
#define SYSCLK_NS (20)

enum : uint64_t {
    /* System clock frequency (50 MHz) */
    system_clock_frequency = 50000000ul,
    /* System clock cycles per microsecond */
    cycles_per_us = (system_clock_frequency / 1000000u),
};

static const uintptr_t dram_base = 0x80000000ul;

/* In order of memory map */
mailbox_t mocha_system_mailbox(void);
gpio_t mocha_system_gpio(void);
clkmgr_t mocha_system_clkmgr(void);
rstmgr_t mocha_system_rstmgr(void);
uart_t mocha_system_uart(void);
i2c_t mocha_system_i2c(void);
spi_device_t mocha_system_spi_device(void);
timer_t mocha_system_timer(void);
plic_t mocha_system_plic(void);
void *mocha_system_dram(void);

void *mocha_system_dv_test_status(void);
