// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] rstmgr_alert_test : uint32_t {
    rstmgr_alert_test_fatal_fault = (1u << 0),
    rstmgr_alert_test_fatal_cnsty_fault = (1u << 1),
} rstmgr_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 4;
    uint32_t : 28;
} rstmgr_reset_req;

typedef struct [[gnu::aligned(4)]] {
    uint32_t por : 1;
    uint32_t low_power_exit : 1;
    uint32_t sw_reset : 1;
    uint32_t hw_req : 4;
    uint32_t : 25;
} rstmgr_reset_info;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 31;
} rstmgr_alert_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 31;
} rstmgr_cpu_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 31;
} rstmgr_sw_rst_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 3;
    uint32_t index : 4;
    uint32_t : 24;
} rstmgr_alert_info_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 3;
    uint32_t index : 4;
    uint32_t : 24;
} rstmgr_cpu_info_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cnt_avail : 4;
    uint32_t : 28;
} rstmgr_alert_info_attr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cnt_avail : 4;
    uint32_t : 28;
} rstmgr_cpu_info_attr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 1;
    uint32_t : 31;
} rstmgr_sw_rst_ctrl_n;

typedef enum [[clang::flag_enum]] rstmgr_err_code : uint32_t {
    rstmgr_err_code_reg_intg_err = (1u << 0),
    rstmgr_err_code_reset_consistency_err = (1u << 1),
    rstmgr_err_code_fsm_err = (1u << 2),
} rstmgr_err_code;

typedef volatile struct [[gnu::aligned(4)]] rstmgr_memory_layout {
    /* rstmgr.alert_test (0x0) */
    rstmgr_alert_test alert_test;

    /* rstmgr.reset_req (0x4) */
    rstmgr_reset_req reset_req;

    /* rstmgr.reset_info (0x8) */
    rstmgr_reset_info reset_info;

    /* rstmgr.alert_regwen (0xc) */
    rstmgr_alert_regwen alert_regwen;

    /* rstmgr.alert_info_ctrl (0x10) */
    rstmgr_alert_info_ctrl alert_info_ctrl;

    /* rstmgr.alert_info_attr (0x14) */
    const rstmgr_alert_info_attr alert_info_attr;

    /* rstmgr.alert_info (0x18) */
    const uint32_t alert_info;

    /* rstmgr.cpu_regwen (0x1c) */
    rstmgr_cpu_regwen cpu_regwen;

    /* rstmgr.cpu_info_ctrl (0x20) */
    rstmgr_cpu_info_ctrl cpu_info_ctrl;

    /* rstmgr.cpu_info_attr (0x24) */
    const rstmgr_cpu_info_attr cpu_info_attr;

    /* rstmgr.cpu_info (0x28) */
    const uint32_t cpu_info;

    /* rstmgr.sw_rst_regwen (0x2c-0x34) */
    rstmgr_sw_rst_regwen sw_rst_regwen[3];

    /* rstmgr.sw_rst_ctrl_n (0x38-0x40) */
    rstmgr_sw_rst_ctrl_n sw_rst_ctrl_n[3];

    /* rstmgr.err_code (0x44) */
    const rstmgr_err_code err_code;
} *rstmgr_t;

_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, alert_test) == 0x0ul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, reset_req) == 0x4ul,
               "incorrect register reset_req offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, reset_info) == 0x8ul,
               "incorrect register reset_info offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, alert_regwen) == 0xcul,
               "incorrect register alert_regwen offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, alert_info_ctrl) == 0x10ul,
               "incorrect register alert_info_ctrl offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, alert_info_attr) == 0x14ul,
               "incorrect register alert_info_attr offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, alert_info) == 0x18ul,
               "incorrect register alert_info offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, cpu_regwen) == 0x1cul,
               "incorrect register cpu_regwen offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, cpu_info_ctrl) == 0x20ul,
               "incorrect register cpu_info_ctrl offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, cpu_info_attr) == 0x24ul,
               "incorrect register cpu_info_attr offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, cpu_info) == 0x28ul,
               "incorrect register cpu_info offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, sw_rst_regwen) == 0x2cul,
               "incorrect register sw_rst_regwen offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, sw_rst_ctrl_n) == 0x38ul,
               "incorrect register sw_rst_ctrl_n offset");
_Static_assert(__builtin_offsetof(struct rstmgr_memory_layout, err_code) == 0x44ul,
               "incorrect register err_code offset");

_Static_assert(sizeof(rstmgr_alert_test) == sizeof(uint32_t),
               "register type rstmgr_alert_test is not register sized");
_Static_assert(sizeof(rstmgr_reset_req) == sizeof(uint32_t),
               "register type rstmgr_reset_req is not register sized");
_Static_assert(sizeof(rstmgr_reset_info) == sizeof(uint32_t),
               "register type rstmgr_reset_info is not register sized");
_Static_assert(sizeof(rstmgr_alert_regwen) == sizeof(uint32_t),
               "register type rstmgr_alert_regwen is not register sized");
_Static_assert(sizeof(rstmgr_cpu_regwen) == sizeof(uint32_t),
               "register type rstmgr_cpu_regwen is not register sized");
_Static_assert(sizeof(rstmgr_sw_rst_regwen) == sizeof(uint32_t),
               "register type rstmgr_sw_rst_regwen is not register sized");
_Static_assert(sizeof(rstmgr_alert_info_ctrl) == sizeof(uint32_t),
               "register type rstmgr_alert_info_ctrl is not register sized");
_Static_assert(sizeof(rstmgr_cpu_info_ctrl) == sizeof(uint32_t),
               "register type rstmgr_cpu_info_ctrl is not register sized");
_Static_assert(sizeof(rstmgr_alert_info_attr) == sizeof(uint32_t),
               "register type rstmgr_alert_info_attr is not register sized");
_Static_assert(sizeof(rstmgr_cpu_info_attr) == sizeof(uint32_t),
               "register type rstmgr_cpu_info_attr is not register sized");
_Static_assert(sizeof(rstmgr_sw_rst_ctrl_n) == sizeof(uint32_t),
               "register type rstmgr_sw_rst_ctrl_n is not register sized");
_Static_assert(sizeof(rstmgr_err_code) == sizeof(uint32_t),
               "register type rstmgr_err_code is not register sized");
