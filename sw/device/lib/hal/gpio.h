// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define GPIO_NUM_PINS (32)

#define GPIO_REG_DATA_IN          (0x10)
#define GPIO_REG_DIRECT_OUT       (0x14)
#define GPIO_REG_MASKED_OUT_LOWER (0x18)
#define GPIO_REG_MASKED_OUT_UPPER (0x1C)
#define GPIO_REG_DIRECT_OE        (0x20)
#define GPIO_REG_MASKED_OE_LOWER  (0x24)
#define GPIO_REG_MASKED_OE_UPPER  (0x28)

typedef void *gpio_t;

// Read the value of one input pin
bool gpio_read_pin(gpio_t gpio, uint32_t pin);

// Set the value of one output pin
void gpio_write_pin(gpio_t gpio, uint32_t pin, bool state);

// Set the value of all output pins
void gpio_write(gpio_t gpio, uint32_t output_reg_addr, uint32_t value);

// Set the output enable state of one pin
void gpio_set_oe_pin(gpio_t gpio, uint32_t pin, bool output);

// Set the output enable state of all pins
void gpio_set_all_oe(gpio_t gpio, uint32_t value);
