// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] entropy_src_intr : uint32_t {
    entropy_src_intr_es_entropy_valid = (1u << 0),
    entropy_src_intr_es_health_test_failed = (1u << 1),
    entropy_src_intr_es_observe_fifo_ready = (1u << 2),
    entropy_src_intr_es_fatal_err = (1u << 3),
} entropy_src_intr;

typedef enum [[clang::flag_enum]] entropy_src_alert_test : uint32_t {
    entropy_src_alert_test_recov_alert = (1u << 0),
    entropy_src_alert_test_fatal_alert = (1u << 1),
} entropy_src_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t me_regwen : 1;
    uint32_t : 31;
} entropy_src_me_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t sw_regupd : 1;
    uint32_t : 31;
} entropy_src_sw_regupd;

typedef struct [[gnu::aligned(4)]] {
    uint32_t regwen : 1;
    uint32_t : 31;
} entropy_src_regwen;

typedef struct [[gnu::aligned(4)]] {
    uint32_t module_enable : 4;
    uint32_t : 28;
} entropy_src_module_enable;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_enable : 4;
    uint32_t fips_flag : 4;
    uint32_t rng_fips : 4;
    uint32_t rng_bit_enable : 4;
    uint32_t threshold_scope : 4;
    uint32_t entropy_data_reg_enable : 4;
    uint32_t rng_bit_sel : 8;
} entropy_src_conf;

typedef struct [[gnu::aligned(4)]] {
    uint32_t es_route : 4;
    uint32_t es_type : 4;
    uint32_t : 24;
} entropy_src_entropy_control;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_window : 16;
    uint32_t bypass_window : 16;
} entropy_src_health_test_windows;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_repcnt_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_repcnts_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_adaptp_hi_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_adaptp_lo_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_bucket_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_markov_hi_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_markov_lo_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_extht_hi_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_thresh : 16;
    uint32_t bypass_thresh : 16;
} entropy_src_extht_lo_thresholds;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_repcnt_hi_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_repcnts_hi_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_adaptp_hi_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_adaptp_lo_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_extht_hi_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_extht_lo_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_bucket_hi_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_markov_hi_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_watermark : 16;
    uint32_t bypass_watermark : 16;
} entropy_src_markov_lo_watermarks;

typedef struct [[gnu::aligned(4)]] {
    uint32_t alert_threshold : 16;
    uint32_t alert_threshold_inv : 16;
} entropy_src_alert_threshold;

typedef struct [[gnu::aligned(4)]] {
    uint32_t any_fail_count : 16;
    uint32_t : 16;
} entropy_src_alert_summary_fail_counts;

typedef struct [[gnu::aligned(4)]] {
    uint32_t : 3;
    uint32_t repcnt_fail_count : 4;
    uint32_t adaptp_hi_fail_count : 4;
    uint32_t adaptp_lo_fail_count : 4;
    uint32_t bucket_fail_count : 4;
    uint32_t markov_hi_fail_count : 4;
    uint32_t markov_lo_fail_count : 4;
    uint32_t repcnts_fail_count : 4;
} entropy_src_alert_fail_counts;

typedef struct [[gnu::aligned(4)]] {
    uint32_t extht_hi_fail_count : 4;
    uint32_t extht_lo_fail_count : 4;
    uint32_t : 24;
} entropy_src_extht_fail_counts;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fw_ov_mode : 4;
    uint32_t fw_ov_entropy_insert : 4;
    uint32_t : 24;
} entropy_src_fw_ov_control;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fw_ov_insert_start : 4;
    uint32_t : 28;
} entropy_src_fw_ov_sha3_start;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fw_ov_wr_fifo_full : 1;
    uint32_t : 31;
} entropy_src_fw_ov_wr_fifo_full;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fw_ov_rd_fifo_overflow : 1;
    uint32_t : 31;
} entropy_src_fw_ov_rd_fifo_overflow;

typedef struct [[gnu::aligned(4)]] {
    uint32_t observe_fifo_thresh : 6;
    uint32_t : 26;
} entropy_src_observe_fifo_thresh;

typedef struct [[gnu::aligned(4)]] {
    uint32_t observe_fifo_depth : 6;
    uint32_t : 26;
} entropy_src_observe_fifo_depth;

typedef struct [[gnu::aligned(4)]] {
    uint32_t entropy_fifo_depth : 2;
    uint32_t : 1;
    uint32_t sha3_fsm : 3;
    uint32_t sha3_block_pr : 1;
    uint32_t sha3_squeezing : 1;
    uint32_t sha3_absorbed : 1;
    uint32_t sha3_err : 1;
    uint32_t : 6;
    uint32_t main_sm_idle : 1;
    uint32_t main_sm_boot_done : 1;
    uint32_t : 14;
} entropy_src_debug_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fips_enable_field_alert : 1;
    uint32_t entropy_data_reg_en_field_alert : 1;
    uint32_t module_enable_field_alert : 1;
    uint32_t threshold_scope_field_alert : 1;
    uint32_t : 1;
    uint32_t rng_bit_enable_field_alert : 1;
    uint32_t : 1;
    uint32_t fw_ov_sha3_start_field_alert : 1;
    uint32_t fw_ov_mode_field_alert : 1;
    uint32_t fw_ov_entropy_insert_field_alert : 1;
    uint32_t es_route_field_alert : 1;
    uint32_t es_type_field_alert : 1;
    uint32_t es_main_sm_alert : 1;
    uint32_t es_bus_cmp_alert : 1;
    uint32_t es_thresh_cfg_alert : 1;
    uint32_t es_fw_ov_wr_alert : 1;
    uint32_t es_fw_ov_disable_alert : 1;
    uint32_t fips_flag_field_alert : 1;
    uint32_t rng_fips_field_alert : 1;
    uint32_t : 12;
    uint32_t postht_entropy_drop_alert : 1;
} entropy_src_recov_alert_sts;

typedef struct [[gnu::aligned(4)]] {
    uint32_t sfifo_esrng_err : 1;
    uint32_t sfifo_distr_err : 1;
    uint32_t sfifo_observe_err : 1;
    uint32_t sfifo_esfinal_err : 1;
    uint32_t : 16;
    uint32_t es_ack_sm_err : 1;
    uint32_t es_main_sm_err : 1;
    uint32_t es_cntr_err : 1;
    uint32_t sha3_state_err : 1;
    uint32_t sha3_rst_storage_err : 1;
    uint32_t : 3;
    uint32_t fifo_write_err : 1;
    uint32_t fifo_read_err : 1;
    uint32_t fifo_state_err : 1;
    uint32_t : 1;
} entropy_src_err_code;

typedef struct [[gnu::aligned(4)]] {
    uint32_t err_code_test : 5;
    uint32_t : 27;
} entropy_src_err_code_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t main_sm_state : 9;
    uint32_t : 23;
} entropy_src_main_sm_state;

typedef volatile struct [[gnu::aligned(4)]] entropy_src_memory_layout {
    /* entropy_src.intr_state (0x0) */
    entropy_src_intr intr_state;

    /* entropy_src.intr_enable (0x4) */
    entropy_src_intr intr_enable;

    /* entropy_src.intr_test (0x8) */
    entropy_src_intr intr_test;

    /* entropy_src.alert_test (0xc) */
    entropy_src_alert_test alert_test;

    /* entropy_src.me_regwen (0x10) */
    entropy_src_me_regwen me_regwen;

    /* entropy_src.sw_regupd (0x14) */
    entropy_src_sw_regupd sw_regupd;

    /* entropy_src.regwen (0x18) */
    const entropy_src_regwen regwen;

    /* entropy_src.module_enable (0x1c) */
    entropy_src_module_enable module_enable;

    /* entropy_src.conf (0x20) */
    entropy_src_conf conf;

    /* entropy_src.entropy_control (0x24) */
    entropy_src_entropy_control entropy_control;

    /* entropy_src.entropy_data (0x28) */
    const uint32_t entropy_data;

    /* entropy_src.health_test_windows (0x2c) */
    entropy_src_health_test_windows health_test_windows;

    /* entropy_src.repcnt_thresholds (0x30) */
    entropy_src_repcnt_thresholds repcnt_thresholds;

    /* entropy_src.repcnts_thresholds (0x34) */
    entropy_src_repcnts_thresholds repcnts_thresholds;

    /* entropy_src.adaptp_hi_thresholds (0x38) */
    entropy_src_adaptp_hi_thresholds adaptp_hi_thresholds;

    /* entropy_src.adaptp_lo_thresholds (0x3c) */
    entropy_src_adaptp_lo_thresholds adaptp_lo_thresholds;

    /* entropy_src.bucket_thresholds (0x40) */
    entropy_src_bucket_thresholds bucket_thresholds;

    /* entropy_src.markov_hi_thresholds (0x44) */
    entropy_src_markov_hi_thresholds markov_hi_thresholds;

    /* entropy_src.markov_lo_thresholds (0x48) */
    entropy_src_markov_lo_thresholds markov_lo_thresholds;

    /* entropy_src.extht_hi_thresholds (0x4c) */
    entropy_src_extht_hi_thresholds extht_hi_thresholds;

    /* entropy_src.extht_lo_thresholds (0x50) */
    entropy_src_extht_lo_thresholds extht_lo_thresholds;

    /* entropy_src.repcnt_hi_watermarks (0x54) */
    const entropy_src_repcnt_hi_watermarks repcnt_hi_watermarks;

    /* entropy_src.repcnts_hi_watermarks (0x58) */
    const entropy_src_repcnts_hi_watermarks repcnts_hi_watermarks;

    /* entropy_src.adaptp_hi_watermarks (0x5c) */
    const entropy_src_adaptp_hi_watermarks adaptp_hi_watermarks;

    /* entropy_src.adaptp_lo_watermarks (0x60) */
    const entropy_src_adaptp_lo_watermarks adaptp_lo_watermarks;

    /* entropy_src.extht_hi_watermarks (0x64) */
    const entropy_src_extht_hi_watermarks extht_hi_watermarks;

    /* entropy_src.extht_lo_watermarks (0x68) */
    const entropy_src_extht_lo_watermarks extht_lo_watermarks;

    /* entropy_src.bucket_hi_watermarks (0x6c) */
    const entropy_src_bucket_hi_watermarks bucket_hi_watermarks;

    /* entropy_src.markov_hi_watermarks (0x70) */
    const entropy_src_markov_hi_watermarks markov_hi_watermarks;

    /* entropy_src.markov_lo_watermarks (0x74) */
    const entropy_src_markov_lo_watermarks markov_lo_watermarks;

    /* entropy_src.repcnt_total_fails (0x78) */
    const uint32_t repcnt_total_fails;

    /* entropy_src.repcnts_total_fails (0x7c) */
    const uint32_t repcnts_total_fails;

    /* entropy_src.adaptp_hi_total_fails (0x80) */
    const uint32_t adaptp_hi_total_fails;

    /* entropy_src.adaptp_lo_total_fails (0x84) */
    const uint32_t adaptp_lo_total_fails;

    /* entropy_src.bucket_total_fails (0x88) */
    const uint32_t bucket_total_fails;

    /* entropy_src.markov_hi_total_fails (0x8c) */
    const uint32_t markov_hi_total_fails;

    /* entropy_src.markov_lo_total_fails (0x90) */
    const uint32_t markov_lo_total_fails;

    /* entropy_src.extht_hi_total_fails (0x94) */
    const uint32_t extht_hi_total_fails;

    /* entropy_src.extht_lo_total_fails (0x98) */
    const uint32_t extht_lo_total_fails;

    /* entropy_src.alert_threshold (0x9c) */
    entropy_src_alert_threshold alert_threshold;

    /* entropy_src.alert_summary_fail_counts (0xa0) */
    const entropy_src_alert_summary_fail_counts alert_summary_fail_counts;

    /* entropy_src.alert_fail_counts (0xa4) */
    const entropy_src_alert_fail_counts alert_fail_counts;

    /* entropy_src.extht_fail_counts (0xa8) */
    const entropy_src_extht_fail_counts extht_fail_counts;

    /* entropy_src.fw_ov_control (0xac) */
    entropy_src_fw_ov_control fw_ov_control;

    /* entropy_src.fw_ov_sha3_start (0xb0) */
    entropy_src_fw_ov_sha3_start fw_ov_sha3_start;

    /* entropy_src.fw_ov_wr_fifo_full (0xb4) */
    const entropy_src_fw_ov_wr_fifo_full fw_ov_wr_fifo_full;

    /* entropy_src.fw_ov_rd_fifo_overflow (0xb8) */
    const entropy_src_fw_ov_rd_fifo_overflow fw_ov_rd_fifo_overflow;

    /* entropy_src.fw_ov_rd_data (0xbc) */
    const uint32_t fw_ov_rd_data;

    /* entropy_src.fw_ov_wr_data (0xc0) */
    uint32_t fw_ov_wr_data;

    /* entropy_src.observe_fifo_thresh (0xc4) */
    entropy_src_observe_fifo_thresh observe_fifo_thresh;

    /* entropy_src.observe_fifo_depth (0xc8) */
    const entropy_src_observe_fifo_depth observe_fifo_depth;

    /* entropy_src.debug_status (0xcc) */
    const entropy_src_debug_status debug_status;

    /* entropy_src.recov_alert_sts (0xd0) */
    entropy_src_recov_alert_sts recov_alert_sts;

    /* entropy_src.err_code (0xd4) */
    const entropy_src_err_code err_code;

    /* entropy_src.err_code_test (0xd8) */
    entropy_src_err_code_test err_code_test;

    /* entropy_src.main_sm_state (0xdc) */
    const entropy_src_main_sm_state main_sm_state;
} *entropy_src_t;

_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, me_regwen) == 0x10ul,
               "incorrect register me_regwen offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, sw_regupd) == 0x14ul,
               "incorrect register sw_regupd offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, regwen) == 0x18ul,
               "incorrect register regwen offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, module_enable) == 0x1cul,
               "incorrect register module_enable offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, conf) == 0x20ul,
               "incorrect register conf offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, entropy_control) == 0x24ul,
               "incorrect register entropy_control offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, entropy_data) == 0x28ul,
               "incorrect register entropy_data offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, health_test_windows) == 0x2cul,
               "incorrect register health_test_windows offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, repcnt_thresholds) == 0x30ul,
               "incorrect register repcnt_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, repcnts_thresholds) == 0x34ul,
               "incorrect register repcnts_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, adaptp_hi_thresholds) == 0x38ul,
               "incorrect register adaptp_hi_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, adaptp_lo_thresholds) == 0x3cul,
               "incorrect register adaptp_lo_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, bucket_thresholds) == 0x40ul,
               "incorrect register bucket_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, markov_hi_thresholds) == 0x44ul,
               "incorrect register markov_hi_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, markov_lo_thresholds) == 0x48ul,
               "incorrect register markov_lo_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_hi_thresholds) == 0x4cul,
               "incorrect register extht_hi_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_lo_thresholds) == 0x50ul,
               "incorrect register extht_lo_thresholds offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, repcnt_hi_watermarks) == 0x54ul,
               "incorrect register repcnt_hi_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, repcnts_hi_watermarks) ==
                   0x58ul,
               "incorrect register repcnts_hi_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, adaptp_hi_watermarks) == 0x5cul,
               "incorrect register adaptp_hi_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, adaptp_lo_watermarks) == 0x60ul,
               "incorrect register adaptp_lo_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_hi_watermarks) == 0x64ul,
               "incorrect register extht_hi_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_lo_watermarks) == 0x68ul,
               "incorrect register extht_lo_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, bucket_hi_watermarks) == 0x6cul,
               "incorrect register bucket_hi_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, markov_hi_watermarks) == 0x70ul,
               "incorrect register markov_hi_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, markov_lo_watermarks) == 0x74ul,
               "incorrect register markov_lo_watermarks offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, repcnt_total_fails) == 0x78ul,
               "incorrect register repcnt_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, repcnts_total_fails) == 0x7cul,
               "incorrect register repcnts_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, adaptp_hi_total_fails) ==
                   0x80ul,
               "incorrect register adaptp_hi_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, adaptp_lo_total_fails) ==
                   0x84ul,
               "incorrect register adaptp_lo_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, bucket_total_fails) == 0x88ul,
               "incorrect register bucket_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, markov_hi_total_fails) ==
                   0x8cul,
               "incorrect register markov_hi_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, markov_lo_total_fails) ==
                   0x90ul,
               "incorrect register markov_lo_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_hi_total_fails) == 0x94ul,
               "incorrect register extht_hi_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_lo_total_fails) == 0x98ul,
               "incorrect register extht_lo_total_fails offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, alert_threshold) == 0x9cul,
               "incorrect register alert_threshold offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, alert_summary_fail_counts) ==
                   0xa0ul,
               "incorrect register alert_summary_fail_counts offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, alert_fail_counts) == 0xa4ul,
               "incorrect register alert_fail_counts offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, extht_fail_counts) == 0xa8ul,
               "incorrect register extht_fail_counts offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, fw_ov_control) == 0xacul,
               "incorrect register fw_ov_control offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, fw_ov_sha3_start) == 0xb0ul,
               "incorrect register fw_ov_sha3_start offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, fw_ov_wr_fifo_full) == 0xb4ul,
               "incorrect register fw_ov_wr_fifo_full offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, fw_ov_rd_fifo_overflow) ==
                   0xb8ul,
               "incorrect register fw_ov_rd_fifo_overflow offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, fw_ov_rd_data) == 0xbcul,
               "incorrect register fw_ov_rd_data offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, fw_ov_wr_data) == 0xc0ul,
               "incorrect register fw_ov_wr_data offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, observe_fifo_thresh) == 0xc4ul,
               "incorrect register observe_fifo_thresh offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, observe_fifo_depth) == 0xc8ul,
               "incorrect register observe_fifo_depth offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, debug_status) == 0xccul,
               "incorrect register debug_status offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, recov_alert_sts) == 0xd0ul,
               "incorrect register recov_alert_sts offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, err_code) == 0xd4ul,
               "incorrect register err_code offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, err_code_test) == 0xd8ul,
               "incorrect register err_code_test offset");
_Static_assert(__builtin_offsetof(struct entropy_src_memory_layout, main_sm_state) == 0xdcul,
               "incorrect register main_sm_state offset");

_Static_assert(sizeof(entropy_src_intr) == sizeof(uint32_t),
               "register type entropy_src_intr is not register sized");
_Static_assert(sizeof(entropy_src_alert_test) == sizeof(uint32_t),
               "register type entropy_src_alert_test is not register sized");
_Static_assert(sizeof(entropy_src_me_regwen) == sizeof(uint32_t),
               "register type entropy_src_me_regwen is not register sized");
_Static_assert(sizeof(entropy_src_sw_regupd) == sizeof(uint32_t),
               "register type entropy_src_sw_regupd is not register sized");
_Static_assert(sizeof(entropy_src_regwen) == sizeof(uint32_t),
               "register type entropy_src_regwen is not register sized");
_Static_assert(sizeof(entropy_src_module_enable) == sizeof(uint32_t),
               "register type entropy_src_module_enable is not register sized");
_Static_assert(sizeof(entropy_src_conf) == sizeof(uint32_t),
               "register type entropy_src_conf is not register sized");
_Static_assert(sizeof(entropy_src_entropy_control) == sizeof(uint32_t),
               "register type entropy_src_entropy_control is not register sized");
_Static_assert(sizeof(entropy_src_health_test_windows) == sizeof(uint32_t),
               "register type entropy_src_health_test_windows is not register sized");
_Static_assert(sizeof(entropy_src_repcnt_thresholds) == sizeof(uint32_t),
               "register type entropy_src_repcnt_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_repcnts_thresholds) == sizeof(uint32_t),
               "register type entropy_src_repcnts_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_adaptp_hi_thresholds) == sizeof(uint32_t),
               "register type entropy_src_adaptp_hi_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_adaptp_lo_thresholds) == sizeof(uint32_t),
               "register type entropy_src_adaptp_lo_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_bucket_thresholds) == sizeof(uint32_t),
               "register type entropy_src_bucket_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_markov_hi_thresholds) == sizeof(uint32_t),
               "register type entropy_src_markov_hi_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_markov_lo_thresholds) == sizeof(uint32_t),
               "register type entropy_src_markov_lo_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_extht_hi_thresholds) == sizeof(uint32_t),
               "register type entropy_src_extht_hi_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_extht_lo_thresholds) == sizeof(uint32_t),
               "register type entropy_src_extht_lo_thresholds is not register sized");
_Static_assert(sizeof(entropy_src_repcnt_hi_watermarks) == sizeof(uint32_t),
               "register type entropy_src_repcnt_hi_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_repcnts_hi_watermarks) == sizeof(uint32_t),
               "register type entropy_src_repcnts_hi_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_adaptp_hi_watermarks) == sizeof(uint32_t),
               "register type entropy_src_adaptp_hi_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_adaptp_lo_watermarks) == sizeof(uint32_t),
               "register type entropy_src_adaptp_lo_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_extht_hi_watermarks) == sizeof(uint32_t),
               "register type entropy_src_extht_hi_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_extht_lo_watermarks) == sizeof(uint32_t),
               "register type entropy_src_extht_lo_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_bucket_hi_watermarks) == sizeof(uint32_t),
               "register type entropy_src_bucket_hi_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_markov_hi_watermarks) == sizeof(uint32_t),
               "register type entropy_src_markov_hi_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_markov_lo_watermarks) == sizeof(uint32_t),
               "register type entropy_src_markov_lo_watermarks is not register sized");
_Static_assert(sizeof(entropy_src_alert_threshold) == sizeof(uint32_t),
               "register type entropy_src_alert_threshold is not register sized");
_Static_assert(sizeof(entropy_src_alert_summary_fail_counts) == sizeof(uint32_t),
               "register type entropy_src_alert_summary_fail_counts is not register sized");
_Static_assert(sizeof(entropy_src_alert_fail_counts) == sizeof(uint32_t),
               "register type entropy_src_alert_fail_counts is not register sized");
_Static_assert(sizeof(entropy_src_extht_fail_counts) == sizeof(uint32_t),
               "register type entropy_src_extht_fail_counts is not register sized");
_Static_assert(sizeof(entropy_src_fw_ov_control) == sizeof(uint32_t),
               "register type entropy_src_fw_ov_control is not register sized");
_Static_assert(sizeof(entropy_src_fw_ov_sha3_start) == sizeof(uint32_t),
               "register type entropy_src_fw_ov_sha3_start is not register sized");
_Static_assert(sizeof(entropy_src_fw_ov_wr_fifo_full) == sizeof(uint32_t),
               "register type entropy_src_fw_ov_wr_fifo_full is not register sized");
_Static_assert(sizeof(entropy_src_fw_ov_rd_fifo_overflow) == sizeof(uint32_t),
               "register type entropy_src_fw_ov_rd_fifo_overflow is not register sized");
_Static_assert(sizeof(entropy_src_observe_fifo_thresh) == sizeof(uint32_t),
               "register type entropy_src_observe_fifo_thresh is not register sized");
_Static_assert(sizeof(entropy_src_observe_fifo_depth) == sizeof(uint32_t),
               "register type entropy_src_observe_fifo_depth is not register sized");
_Static_assert(sizeof(entropy_src_debug_status) == sizeof(uint32_t),
               "register type entropy_src_debug_status is not register sized");
_Static_assert(sizeof(entropy_src_recov_alert_sts) == sizeof(uint32_t),
               "register type entropy_src_recov_alert_sts is not register sized");
_Static_assert(sizeof(entropy_src_err_code) == sizeof(uint32_t),
               "register type entropy_src_err_code is not register sized");
_Static_assert(sizeof(entropy_src_err_code_test) == sizeof(uint32_t),
               "register type entropy_src_err_code_test is not register sized");
_Static_assert(sizeof(entropy_src_main_sm_state) == sizeof(uint32_t),
               "register type entropy_src_main_sm_state is not register sized");
