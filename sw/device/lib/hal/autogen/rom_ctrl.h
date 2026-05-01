// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal : 1;
    uint32_t : 31;
} rom_ctrl_alert_test;

typedef enum [[clang::flag_enum]] rom_ctrl_fatal_alert_cause : uint32_t {
    rom_ctrl_fatal_alert_cause_checker_error = (1u << 0),
    rom_ctrl_fatal_alert_cause_integrity_error = (1u << 1),
} rom_ctrl_fatal_alert_cause;

typedef volatile struct [[gnu::aligned(4)]] rom_ctrl_memory_layout {
    /* rom_ctrl.alert_test (0x0) */
    rom_ctrl_alert_test alert_test;

    /* rom_ctrl.fatal_alert_cause (0x4) */
    const rom_ctrl_fatal_alert_cause fatal_alert_cause;

    /* rom_ctrl.digest (0x8-0x24) */
    const uint32_t digest[8];

    /* rom_ctrl.exp_digest (0x28-0x44) */
    const uint32_t exp_digest[8];
} *rom_ctrl_t;

_Static_assert(__builtin_offsetof(struct rom_ctrl_memory_layout, alert_test) == 0x0ul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct rom_ctrl_memory_layout, fatal_alert_cause) == 0x4ul,
               "incorrect register fatal_alert_cause offset");
_Static_assert(__builtin_offsetof(struct rom_ctrl_memory_layout, digest) == 0x8ul,
               "incorrect register digest offset");
_Static_assert(__builtin_offsetof(struct rom_ctrl_memory_layout, exp_digest) == 0x28ul,
               "incorrect register exp_digest offset");

_Static_assert(sizeof(rom_ctrl_alert_test) == sizeof(uint32_t),
               "register type rom_ctrl_alert_test is not register sized");
_Static_assert(sizeof(rom_ctrl_fatal_alert_cause) == sizeof(uint32_t),
               "register type rom_ctrl_fatal_alert_cause is not register sized");
