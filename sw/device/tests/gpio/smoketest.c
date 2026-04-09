// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/gpio.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

static bool gpio_test(gpio_t gpio)
{
    uint8_t timeout = 0;

    // Enable the GPIOs in output mode
    DEV_WRITE(gpio + GPIO_REG_DIRECT_OE, 0xFFFFFFFF);

    // Set each pin in walking 1's fashion
    for (int i = 0; i < GPIO_NUM_PINS; i++) {
        DEV_WRITE(gpio + GPIO_REG_DIRECT_OUT, 1 << i);
    }

    // Once the SW finishes driving the walking 1's pattern on the last GPIO pin, it should disable
    // the output enables so that the GPIO pads can safely be driven as inputs
    DEV_WRITE(gpio + GPIO_REG_DIRECT_OE, 0x0);

    // Wait for the pattern of 1's on odd pins and 0's on even pins to be driven externally.
    while (DEV_READ(gpio + GPIO_REG_DATA_IN) != 0x55555555) {
        // The expected pattern is driven externally on the inputs by toggling the wires. Since this
        // occurs without delay in simulation, a timeout of 10 read requests is sufficient to detect
        // a failure.
        if (timeout == 0xA) {
            return false;
        }
        timeout++;
    }

    return true;
}

bool test_main()
{
    gpio_t gpio = mocha_system_gpio();
    return gpio_test(gpio);
}
