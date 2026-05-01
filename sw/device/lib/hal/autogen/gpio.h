// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal_fault : 1;
    uint32_t : 31;
} gpio_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t data : 16;
    uint32_t mask : 16;
} gpio_masked_out_lower;

typedef struct [[gnu::aligned(4)]] {
    uint32_t data : 16;
    uint32_t mask : 16;
} gpio_masked_out_upper;

typedef struct [[gnu::aligned(4)]] {
    uint32_t data : 16;
    uint32_t mask : 16;
} gpio_masked_oe_lower;

typedef struct [[gnu::aligned(4)]] {
    uint32_t data : 16;
    uint32_t mask : 16;
} gpio_masked_oe_upper;

typedef struct [[gnu::aligned(4)]] {
    uint32_t hw_straps_data_in_valid : 1;
    uint32_t : 31;
} gpio_hw_straps_data_in_valid;

typedef volatile struct [[gnu::aligned(4)]] gpio_memory_layout {
    /* gpio.intr_state (0x0) */
    uint32_t intr_state;

    /* gpio.intr_enable (0x4) */
    uint32_t intr_enable;

    /* gpio.intr_test (0x8) */
    uint32_t intr_test;

    /* gpio.alert_test (0xc) */
    gpio_alert_test alert_test;

    /* gpio.data_in (0x10) */
    const uint32_t data_in;

    /* gpio.direct_out (0x14) */
    uint32_t direct_out;

    /* gpio.masked_out_lower (0x18) */
    gpio_masked_out_lower masked_out_lower;

    /* gpio.masked_out_upper (0x1c) */
    gpio_masked_out_upper masked_out_upper;

    /* gpio.direct_oe (0x20) */
    uint32_t direct_oe;

    /* gpio.masked_oe_lower (0x24) */
    gpio_masked_oe_lower masked_oe_lower;

    /* gpio.masked_oe_upper (0x28) */
    gpio_masked_oe_upper masked_oe_upper;

    /* gpio.intr_ctrl_en_rising (0x2c) */
    uint32_t intr_ctrl_en_rising;

    /* gpio.intr_ctrl_en_falling (0x30) */
    uint32_t intr_ctrl_en_falling;

    /* gpio.intr_ctrl_en_lvlhigh (0x34) */
    uint32_t intr_ctrl_en_lvlhigh;

    /* gpio.intr_ctrl_en_lvllow (0x38) */
    uint32_t intr_ctrl_en_lvllow;

    /* gpio.ctrl_en_input_filter (0x3c) */
    uint32_t ctrl_en_input_filter;

    /* gpio.hw_straps_data_in_valid (0x40) */
    const gpio_hw_straps_data_in_valid hw_straps_data_in_valid;

    /* gpio.hw_straps_data_in (0x44) */
    const uint32_t hw_straps_data_in;
} *gpio_t;

_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, data_in) == 0x10ul,
               "incorrect register data_in offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, direct_out) == 0x14ul,
               "incorrect register direct_out offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, masked_out_lower) == 0x18ul,
               "incorrect register masked_out_lower offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, masked_out_upper) == 0x1cul,
               "incorrect register masked_out_upper offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, direct_oe) == 0x20ul,
               "incorrect register direct_oe offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, masked_oe_lower) == 0x24ul,
               "incorrect register masked_oe_lower offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, masked_oe_upper) == 0x28ul,
               "incorrect register masked_oe_upper offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_ctrl_en_rising) == 0x2cul,
               "incorrect register intr_ctrl_en_rising offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_ctrl_en_falling) == 0x30ul,
               "incorrect register intr_ctrl_en_falling offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_ctrl_en_lvlhigh) == 0x34ul,
               "incorrect register intr_ctrl_en_lvlhigh offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, intr_ctrl_en_lvllow) == 0x38ul,
               "incorrect register intr_ctrl_en_lvllow offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, ctrl_en_input_filter) == 0x3cul,
               "incorrect register ctrl_en_input_filter offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, hw_straps_data_in_valid) == 0x40ul,
               "incorrect register hw_straps_data_in_valid offset");
_Static_assert(__builtin_offsetof(struct gpio_memory_layout, hw_straps_data_in) == 0x44ul,
               "incorrect register hw_straps_data_in offset");

_Static_assert(sizeof(gpio_alert_test) == sizeof(uint32_t),
               "register type gpio_alert_test is not register sized");
_Static_assert(sizeof(gpio_masked_out_lower) == sizeof(uint32_t),
               "register type gpio_masked_out_lower is not register sized");
_Static_assert(sizeof(gpio_masked_out_upper) == sizeof(uint32_t),
               "register type gpio_masked_out_upper is not register sized");
_Static_assert(sizeof(gpio_masked_oe_lower) == sizeof(uint32_t),
               "register type gpio_masked_oe_lower is not register sized");
_Static_assert(sizeof(gpio_masked_oe_upper) == sizeof(uint32_t),
               "register type gpio_masked_oe_upper is not register sized");
_Static_assert(sizeof(gpio_hw_straps_data_in_valid) == sizeof(uint32_t),
               "register type gpio_hw_straps_data_in_valid is not register sized");
