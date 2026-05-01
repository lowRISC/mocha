// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] kmac_intr : uint32_t {
    kmac_intr_kmac_done = (1u << 0),
    kmac_intr_fifo_empty = (1u << 1),
    kmac_intr_kmac_err = (1u << 2),
} kmac_intr;

typedef enum [[clang::flag_enum]] kmac_alert_test : uint32_t {
    kmac_alert_test_recov_operation_err = (1u << 0),
    kmac_alert_test_fatal_fault_err = (1u << 1),
} kmac_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t en : 1;
    uint32_t : 31;
} kmac_cfg_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t kmac_en : 1;
    uint32_t kstrength : 3;
    uint32_t mode : 2;
    uint32_t : 2;
    uint32_t msg_endianness : 1;
    uint32_t state_endianness : 1;
    uint32_t : 2;
    uint32_t sideload : 1;
    uint32_t : 3;
    uint32_t entropy_mode : 2;
    uint32_t : 1;
    uint32_t entropy_fast_process : 1;
    uint32_t msg_mask : 1;
    uint32_t : 3;
    uint32_t entropy_ready : 1;
    uint32_t : 1;
    uint32_t en_unsupported_modestrength : 1;
    uint32_t : 5;
} kmac_cfg_shadowed;

typedef struct [[gnu::aligned(4)]] {
    uint32_t cmd : 6;
    uint32_t : 2;
    uint32_t entropy_req : 1;
    uint32_t hash_cnt_clr : 1;
    uint32_t err_processed : 1;
    uint32_t : 21;
} kmac_cmd;

typedef struct [[gnu::aligned(4)]] {
    uint32_t sha3_idle : 1;
    uint32_t sha3_absorb : 1;
    uint32_t sha3_squeeze : 1;
    uint32_t : 5;
    uint32_t fifo_depth : 5;
    uint32_t : 1;
    uint32_t fifo_empty : 1;
    uint32_t fifo_full : 1;
    uint32_t alert_fatal_fault : 1;
    uint32_t alert_recov_ctrl_update_err : 1;
    uint32_t : 14;
} kmac_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t prescaler : 10;
    uint32_t : 6;
    uint32_t wait_timer : 16;
} kmac_entropy_period;

typedef struct [[gnu::aligned(4)]] {
    uint32_t hash_cnt : 10;
    uint32_t : 22;
} kmac_entropy_refresh_hash_cnt;

typedef struct [[gnu::aligned(4)]] {
    uint32_t threshold : 10;
    uint32_t : 22;
} kmac_entropy_refresh_threshold_shadowed;

typedef struct [[gnu::aligned(4)]] {
    uint32_t len : 3;
    uint32_t : 29;
} kmac_key_len;

typedef volatile struct [[gnu::aligned(4)]] kmac_memory_layout {
    /* kmac.intr_state (0x0) */
    kmac_intr intr_state;

    /* kmac.intr_enable (0x4) */
    kmac_intr intr_enable;

    /* kmac.intr_test (0x8) */
    kmac_intr intr_test;

    /* kmac.alert_test (0xc) */
    kmac_alert_test alert_test;

    /* kmac.cfg_regwen (0x10) */
    const kmac_cfg_regwen cfg_regwen;

    /* kmac.cfg_shadowed (0x14) */
    kmac_cfg_shadowed cfg_shadowed;

    /* kmac.cmd (0x18) */
    kmac_cmd cmd;

    /* kmac.status (0x1c) */
    const kmac_status status;

    /* kmac.entropy_period (0x20) */
    kmac_entropy_period entropy_period;

    /* kmac.entropy_refresh_hash_cnt (0x24) */
    const kmac_entropy_refresh_hash_cnt entropy_refresh_hash_cnt;

    /* kmac.entropy_refresh_threshold_shadowed (0x28) */
    kmac_entropy_refresh_threshold_shadowed entropy_refresh_threshold_shadowed;

    /* kmac.entropy_seed (0x2c) */
    uint32_t entropy_seed;

    /* kmac.key_share0 (0x30-0x6c) */
    uint32_t key_share0[16];

    /* kmac.key_share1 (0x70-0xac) */
    uint32_t key_share1[16];

    /* kmac.key_len (0xb0) */
    kmac_key_len key_len;

    /* kmac.prefix (0xb4-0xdc) */
    uint32_t prefix[11];

    /* kmac.err_code (0xe0) */
    const uint32_t err_code;

    const uint8_t __reserved0[0x400 - 0xe4];

    /* kmac.state (0x400-0x5fc) */
    const uint32_t state[128];

    const uint8_t __reserved1[0x800 - 0x600];

    /* kmac.msg_fifo (0x800-0xffc) */
    uint32_t msg_fifo[512];
} *kmac_t;

_Static_assert(__builtin_offsetof(struct kmac_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, cfg_regwen) == 0x10ul,
               "incorrect register cfg_regwen offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, cfg_shadowed) == 0x14ul,
               "incorrect register cfg_shadowed offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, cmd) == 0x18ul,
               "incorrect register cmd offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, status) == 0x1cul,
               "incorrect register status offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, entropy_period) == 0x20ul,
               "incorrect register entropy_period offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, entropy_refresh_hash_cnt) == 0x24ul,
               "incorrect register entropy_refresh_hash_cnt offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, entropy_refresh_threshold_shadowed) ==
                   0x28ul,
               "incorrect register entropy_refresh_threshold_shadowed offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, entropy_seed) == 0x2cul,
               "incorrect register entropy_seed offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, key_share0) == 0x30ul,
               "incorrect register key_share0 offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, key_share1) == 0x70ul,
               "incorrect register key_share1 offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, key_len) == 0xb0ul,
               "incorrect register key_len offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, prefix) == 0xb4ul,
               "incorrect register prefix offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, err_code) == 0xe0ul,
               "incorrect register err_code offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, state) == 0x400ul,
               "incorrect register window state offset");
_Static_assert(__builtin_offsetof(struct kmac_memory_layout, msg_fifo) == 0x800ul,
               "incorrect register window msg_fifo offset");

_Static_assert(sizeof(kmac_intr) == sizeof(uint32_t),
               "register type kmac_intr is not register sized");
_Static_assert(sizeof(kmac_alert_test) == sizeof(uint32_t),
               "register type kmac_alert_test is not register sized");
_Static_assert(sizeof(kmac_cfg_regwen) == sizeof(uint32_t),
               "register type kmac_cfg_regwen is not register sized");
_Static_assert(sizeof(kmac_cfg_shadowed) == sizeof(uint32_t),
               "register type kmac_cfg_shadowed is not register sized");
_Static_assert(sizeof(kmac_cmd) == sizeof(uint32_t),
               "register type kmac_cmd is not register sized");
_Static_assert(sizeof(kmac_status) == sizeof(uint32_t),
               "register type kmac_status is not register sized");
_Static_assert(sizeof(kmac_entropy_period) == sizeof(uint32_t),
               "register type kmac_entropy_period is not register sized");
_Static_assert(sizeof(kmac_entropy_refresh_hash_cnt) == sizeof(uint32_t),
               "register type kmac_entropy_refresh_hash_cnt is not register sized");
_Static_assert(sizeof(kmac_entropy_refresh_threshold_shadowed) == sizeof(uint32_t),
               "register type kmac_entropy_refresh_threshold_shadowed is not register sized");
_Static_assert(sizeof(kmac_key_len) == sizeof(uint32_t),
               "register type kmac_key_len is not register sized");
