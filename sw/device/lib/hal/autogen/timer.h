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
} timer_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t active : 1;
    uint32_t : 31;
} timer_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t ie : 1;
    uint32_t : 31;
} timer_intr_enable0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t is : 1;
    uint32_t : 31;
} timer_intr_state0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t t : 1;
    uint32_t : 31;
} timer_intr_test0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t prescale : 12;
    uint32_t : 4;
    uint32_t step : 8;
    uint32_t : 8;
} timer_cfg0;

typedef volatile struct [[gnu::aligned(4)]] timer_memory_layout {
    /* timer.alert_test (0x0) */
    timer_alert_test alert_test;

    /* timer.ctrl (0x4) */
    timer_ctrl ctrl;

    const uint8_t __reserved0[0x100 - 0x8];

    /* timer.intr_enable0 (0x100) */
    timer_intr_enable0 intr_enable0;

    /* timer.intr_state0 (0x104) */
    timer_intr_state0 intr_state0;

    /* timer.intr_test0 (0x108) */
    timer_intr_test0 intr_test0;

    /* timer.cfg0 (0x10c) */
    timer_cfg0 cfg0;

    /* timer.timer_v_lower0 (0x110) */
    uint32_t timer_v_lower0;

    /* timer.timer_v_upper0 (0x114) */
    uint32_t timer_v_upper0;

    /* timer.compare_lower0_0 (0x118) */
    uint32_t compare_lower0_0;

    /* timer.compare_upper0_0 (0x11c) */
    uint32_t compare_upper0_0;
} *timer_t;

_Static_assert(__builtin_offsetof(struct timer_memory_layout, alert_test) == 0x0ul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, ctrl) == 0x4ul,
               "incorrect register ctrl offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, intr_enable0) == 0x100ul,
               "incorrect register intr_enable0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, intr_state0) == 0x104ul,
               "incorrect register intr_state0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, intr_test0) == 0x108ul,
               "incorrect register intr_test0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, cfg0) == 0x10cul,
               "incorrect register cfg0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, timer_v_lower0) == 0x110ul,
               "incorrect register timer_v_lower0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, timer_v_upper0) == 0x114ul,
               "incorrect register timer_v_upper0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, compare_lower0_0) == 0x118ul,
               "incorrect register compare_lower0_0 offset");
_Static_assert(__builtin_offsetof(struct timer_memory_layout, compare_upper0_0) == 0x11cul,
               "incorrect register compare_upper0_0 offset");

_Static_assert(sizeof(timer_alert_test) == sizeof(uint32_t),
               "register type timer_alert_test is not register sized");
_Static_assert(sizeof(timer_ctrl) == sizeof(uint32_t),
               "register type timer_ctrl is not register sized");
_Static_assert(sizeof(timer_intr_enable0) == sizeof(uint32_t),
               "register type timer_intr_enable0 is not register sized");
_Static_assert(sizeof(timer_intr_state0) == sizeof(uint32_t),
               "register type timer_intr_state0 is not register sized");
_Static_assert(sizeof(timer_intr_test0) == sizeof(uint32_t),
               "register type timer_intr_test0 is not register sized");
_Static_assert(sizeof(timer_cfg0) == sizeof(uint32_t),
               "register type timer_cfg0 is not register sized");
