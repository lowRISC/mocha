// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/gpio.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

/**
 * This implementation assumes that the number of pins (GPIO_NUM_PINS)
 * is less than or equal to 32.
 */

bool gpio_read_pin(gpio_t gpio, uint32_t pin)
{
    return !!(DEV_READ(gpio + GPIO_REG_DATA_IN) & (1u << pin));
}

void gpio_write_pin(gpio_t gpio, uint32_t pin, bool state)
{
    uint32_t reg = pin < 16 ? GPIO_REG_MASKED_OUT_LOWER : GPIO_REG_MASKED_OUT_UPPER;
    uint32_t mask = 1u << (pin & 0xFu);
    DEV_WRITE(gpio + reg, (mask << 16) | (state ? mask : 0u));
}

void gpio_set_oe_pin(gpio_t gpio, uint32_t pin, bool output)
{
    uint32_t reg = pin < 16 ? GPIO_REG_MASKED_OE_LOWER : GPIO_REG_MASKED_OE_UPPER;
    uint32_t mask = 1u << (pin & 0xFu);
    DEV_WRITE(gpio + reg, (mask << 16) | (output ? mask : 0u));
}
