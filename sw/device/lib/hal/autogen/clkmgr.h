// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] clkmgr_alert_test : uint32_t {
    clkmgr_alert_test_recov_fault = (1u << 0),
    clkmgr_alert_test_fatal_fault = (1u << 1),
} clkmgr_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 31;
} clkmgr_jitter_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 31;
} clkmgr_measure_ctrl_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 4;
    uint32_t : 28;
} clkmgr_jitter_enable;

typedef struct [[gnu::aligned(4)]] {
    uint32_t clk_io_peri_en : 1;
    uint32_t : 31;
} clkmgr_clk_enables;

typedef struct [[gnu::aligned(4)]] {
    uint32_t clk_main_hint_hint : 1;
    uint32_t : 31;
} clkmgr_clk_hints;

typedef struct [[gnu::aligned(4)]] {
    uint32_t clk_main_hint_val : 1;
    uint32_t : 31;
} clkmgr_clk_hints_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 4;
    uint32_t : 28;
} clkmgr_io_meas_ctrl_en;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 4;
    uint32_t : 28;
} clkmgr_main_meas_ctrl_en;

typedef struct [[gnu::aligned(4)]] {
    uint32_t hi : 9;
    uint32_t lo : 9;
    uint32_t : 14;
} clkmgr_io_meas_ctrl_shadowed;

typedef struct [[gnu::aligned(4)]] {
    uint32_t hi : 9;
    uint32_t lo : 9;
    uint32_t : 14;
} clkmgr_main_meas_ctrl_shadowed;

typedef enum [[clang::flag_enum]] clkmgr_recov_err_code : uint32_t {
    clkmgr_recov_err_code_shadow_update_err = (1u << 0),
    clkmgr_recov_err_code_io_measure_err = (1u << 1),
    clkmgr_recov_err_code_main_measure_err = (1u << 2),
    clkmgr_recov_err_code_io_timeout_err = (1u << 3),
    clkmgr_recov_err_code_main_timeout_err = (1u << 4),
} clkmgr_recov_err_code;

typedef enum [[clang::flag_enum]] clkmgr_fatal_err_code : uint32_t {
    clkmgr_fatal_err_code_reg_intg = (1u << 0),
    clkmgr_fatal_err_code_idle_cnt = (1u << 1),
    clkmgr_fatal_err_code_shadow_storage_err = (1u << 2),
} clkmgr_fatal_err_code;

typedef volatile struct [[gnu::aligned(4)]] clkmgr_memory_layout {
    /* clkmgr.alert_test (0x0) */
    clkmgr_alert_test alert_test;

    const uint8_t __reserved0[0x10 - 0x4];

    /* clkmgr.jitter_regwen (0x10) */
    clkmgr_jitter_regwen jitter_regwen;

    /* clkmgr.jitter_enable (0x14) */
    clkmgr_jitter_enable jitter_enable;

    /* clkmgr.clk_enables (0x18) */
    clkmgr_clk_enables clk_enables;

    /* clkmgr.clk_hints (0x1c) */
    clkmgr_clk_hints clk_hints;

    /* clkmgr.clk_hints_status (0x20) */
    const clkmgr_clk_hints_status clk_hints_status;

    /* clkmgr.measure_ctrl_regwen (0x24) */
    clkmgr_measure_ctrl_regwen measure_ctrl_regwen;

    /* clkmgr.io_meas_ctrl_en (0x28) */
    clkmgr_io_meas_ctrl_en io_meas_ctrl_en;

    /* clkmgr.io_meas_ctrl_shadowed (0x2c) */
    clkmgr_io_meas_ctrl_shadowed io_meas_ctrl_shadowed;

    /* clkmgr.main_meas_ctrl_en (0x30) */
    clkmgr_main_meas_ctrl_en main_meas_ctrl_en;

    /* clkmgr.main_meas_ctrl_shadowed (0x34) */
    clkmgr_main_meas_ctrl_shadowed main_meas_ctrl_shadowed;

    /* clkmgr.recov_err_code (0x38) */
    clkmgr_recov_err_code recov_err_code;

    /* clkmgr.fatal_err_code (0x3c) */
    const clkmgr_fatal_err_code fatal_err_code;
} *clkmgr_t;

_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, alert_test) == 0x0ul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, jitter_regwen) == 0x10ul,
               "incorrect register jitter_regwen offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, jitter_enable) == 0x14ul,
               "incorrect register jitter_enable offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, clk_enables) == 0x18ul,
               "incorrect register clk_enables offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, clk_hints) == 0x1cul,
               "incorrect register clk_hints offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, clk_hints_status) == 0x20ul,
               "incorrect register clk_hints_status offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, measure_ctrl_regwen) == 0x24ul,
               "incorrect register measure_ctrl_regwen offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, io_meas_ctrl_en) == 0x28ul,
               "incorrect register io_meas_ctrl_en offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, io_meas_ctrl_shadowed) == 0x2cul,
               "incorrect register io_meas_ctrl_shadowed offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, main_meas_ctrl_en) == 0x30ul,
               "incorrect register main_meas_ctrl_en offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, main_meas_ctrl_shadowed) == 0x34ul,
               "incorrect register main_meas_ctrl_shadowed offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, recov_err_code) == 0x38ul,
               "incorrect register recov_err_code offset");
_Static_assert(__builtin_offsetof(struct clkmgr_memory_layout, fatal_err_code) == 0x3cul,
               "incorrect register fatal_err_code offset");

_Static_assert(sizeof(clkmgr_alert_test) == sizeof(uint32_t),
               "register type clkmgr_alert_test is not register sized");
_Static_assert(sizeof(clkmgr_jitter_regwen) == sizeof(uint32_t),
               "register type clkmgr_jitter_regwen is not register sized");
_Static_assert(sizeof(clkmgr_measure_ctrl_regwen) == sizeof(uint32_t),
               "register type clkmgr_measure_ctrl_regwen is not register sized");
_Static_assert(sizeof(clkmgr_jitter_enable) == sizeof(uint32_t),
               "register type clkmgr_jitter_enable is not register sized");
_Static_assert(sizeof(clkmgr_clk_enables) == sizeof(uint32_t),
               "register type clkmgr_clk_enables is not register sized");
_Static_assert(sizeof(clkmgr_clk_hints) == sizeof(uint32_t),
               "register type clkmgr_clk_hints is not register sized");
_Static_assert(sizeof(clkmgr_clk_hints_status) == sizeof(uint32_t),
               "register type clkmgr_clk_hints_status is not register sized");
_Static_assert(sizeof(clkmgr_io_meas_ctrl_en) == sizeof(uint32_t),
               "register type clkmgr_io_meas_ctrl_en is not register sized");
_Static_assert(sizeof(clkmgr_main_meas_ctrl_en) == sizeof(uint32_t),
               "register type clkmgr_main_meas_ctrl_en is not register sized");
_Static_assert(sizeof(clkmgr_io_meas_ctrl_shadowed) == sizeof(uint32_t),
               "register type clkmgr_io_meas_ctrl_shadowed is not register sized");
_Static_assert(sizeof(clkmgr_main_meas_ctrl_shadowed) == sizeof(uint32_t),
               "register type clkmgr_main_meas_ctrl_shadowed is not register sized");
_Static_assert(sizeof(clkmgr_recov_err_code) == sizeof(uint32_t),
               "register type clkmgr_recov_err_code is not register sized");
_Static_assert(sizeof(clkmgr_fatal_err_code) == sizeof(uint32_t),
               "register type clkmgr_fatal_err_code is not register sized");
