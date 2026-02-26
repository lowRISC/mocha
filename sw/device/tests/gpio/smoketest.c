// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/gpio.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

// Check that we can write and read some GPIO registers
static bool reg_test(gpio_t gpio)
{
    uint32_t hal_val;

    // Inputs
    hal_val = 0;
    for (int ii = 0; ii < GPIO_NUM_PINS; ii++) {
        hal_val |= (gpio_read_pin(gpio, ii) << ii);
    }
    if (hal_val != DEV_READ(gpio + GPIO_REG_DATA_IN)) {
        return false;
    }

    // Outputs
    hal_val = 0xC1A0; // Ciao!
    for (int nn = 0; nn < 2; nn++) {
        for (int ii = 0; ii < GPIO_NUM_PINS; ii++) {
            gpio_write_pin(gpio, ii, ((hal_val >> ii) & 0x1));
        }
        if (hal_val != DEV_READ(gpio + GPIO_REG_DIRECT_OUT)) {
            return false;
        }
        hal_val = ~hal_val; // invert to check for constant bits
    }

    // Output enables
    hal_val = 0xB7EE; // Byee!
    for (int nn = 0; nn < 2; nn++) {
        for (int ii = 0; ii < GPIO_NUM_PINS; ii++) {
            gpio_set_oe_pin(gpio, ii, ((hal_val >> ii) & 0x1));
        }
        if (hal_val != DEV_READ(gpio + GPIO_REG_DIRECT_OE)) {
            return false;
        }
        hal_val = ~hal_val; // invert to check for constant bits
    }

    return true;
}

bool test_main()
{
    gpio_t gpio = mocha_system_gpio();
    return reg_test(gpio);
}
