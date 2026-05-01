// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] i2c_intr : uint32_t {
    i2c_intr_fmt_threshold = (1u << 0),
    i2c_intr_rx_threshold = (1u << 1),
    i2c_intr_acq_threshold = (1u << 2),
    i2c_intr_rx_overflow = (1u << 3),
    i2c_intr_controller_halt = (1u << 4),
    i2c_intr_scl_interference = (1u << 5),
    i2c_intr_sda_interference = (1u << 6),
    i2c_intr_stretch_timeout = (1u << 7),
    i2c_intr_sda_unstable = (1u << 8),
    i2c_intr_cmd_complete = (1u << 9),
    i2c_intr_tx_stretch = (1u << 10),
    i2c_intr_tx_threshold = (1u << 11),
    i2c_intr_acq_stretch = (1u << 12),
    i2c_intr_unexp_stop = (1u << 13),
    i2c_intr_host_timeout = (1u << 14),
} i2c_intr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal_fault : 1;
    uint32_t : 31;
} i2c_alert_test;

typedef enum [[clang::flag_enum]] i2c_ctrl : uint32_t {
    i2c_ctrl_enablehost = (1u << 0),
    i2c_ctrl_enabletarget = (1u << 1),
    i2c_ctrl_llpbk = (1u << 2),
    i2c_ctrl_nack_addr_after_timeout = (1u << 3),
    i2c_ctrl_ack_ctrl_en = (1u << 4),
    i2c_ctrl_multi_controller_monitor_en = (1u << 5),
    i2c_ctrl_tx_stretch_ctrl_en = (1u << 6),
} i2c_ctrl;

typedef enum [[clang::flag_enum]] i2c_status : uint32_t {
    i2c_status_fmtfull = (1u << 0),
    i2c_status_rxfull = (1u << 1),
    i2c_status_fmtempty = (1u << 2),
    i2c_status_hostidle = (1u << 3),
    i2c_status_targetidle = (1u << 4),
    i2c_status_rxempty = (1u << 5),
    i2c_status_txfull = (1u << 6),
    i2c_status_acqfull = (1u << 7),
    i2c_status_txempty = (1u << 8),
    i2c_status_acqempty = (1u << 9),
    i2c_status_ack_ctrl_stretch = (1u << 10),
} i2c_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rdata : 8;
    uint32_t : 24;
} i2c_rdata;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fbyte : 8;
    uint32_t start : 1;
    uint32_t stop : 1;
    uint32_t readb : 1;
    uint32_t rcont : 1;
    uint32_t nakok : 1;
    uint32_t : 19;
} i2c_fdata;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rxrst : 1;
    uint32_t fmtrst : 1;
    uint32_t : 5;
    uint32_t acqrst : 1;
    uint32_t txrst : 1;
    uint32_t : 23;
} i2c_fifo_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rx_thresh : 12;
    uint32_t : 4;
    uint32_t fmt_thresh : 12;
    uint32_t : 4;
} i2c_host_fifo_config;

typedef struct [[gnu::aligned(4)]] {
    uint32_t tx_thresh : 12;
    uint32_t : 4;
    uint32_t acq_thresh : 12;
    uint32_t : 4;
} i2c_target_fifo_config;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fmtlvl : 12;
    uint32_t : 4;
    uint32_t rxlvl : 12;
    uint32_t : 4;
} i2c_host_fifo_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t txlvl : 12;
    uint32_t : 4;
    uint32_t acqlvl : 12;
    uint32_t : 4;
} i2c_target_fifo_status;

typedef enum [[clang::flag_enum]] i2c_ovrd : uint32_t {
    i2c_ovrd_txovrden = (1u << 0),
    i2c_ovrd_sclval = (1u << 1),
    i2c_ovrd_sdaval = (1u << 2),
} i2c_ovrd;

typedef struct [[gnu::aligned(4)]] {
    uint32_t scl_rx : 16;
    uint32_t sda_rx : 16;
} i2c_val;

typedef struct [[gnu::aligned(4)]] {
    uint32_t thigh : 13;
    uint32_t : 3;
    uint32_t tlow : 13;
    uint32_t : 3;
} i2c_timing0;

typedef struct [[gnu::aligned(4)]] {
    uint32_t t_r : 10;
    uint32_t : 6;
    uint32_t t_f : 9;
    uint32_t : 7;
} i2c_timing1;

typedef struct [[gnu::aligned(4)]] {
    uint32_t tsu_sta : 13;
    uint32_t : 3;
    uint32_t thd_sta : 13;
    uint32_t : 3;
} i2c_timing2;

typedef struct [[gnu::aligned(4)]] {
    uint32_t tsu_dat : 9;
    uint32_t : 7;
    uint32_t thd_dat : 13;
    uint32_t : 3;
} i2c_timing3;

typedef struct [[gnu::aligned(4)]] {
    uint32_t tsu_sto : 13;
    uint32_t : 3;
    uint32_t t_buf : 13;
    uint32_t : 3;
} i2c_timing4;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 30;
    uint32_t mode : 1;
    uint32_t en : 1;
} i2c_timeout_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t address0 : 7;
    uint32_t mask0 : 7;
    uint32_t address1 : 7;
    uint32_t mask1 : 7;
    uint32_t : 4;
} i2c_target_id;

typedef struct [[gnu::aligned(4)]] {
    uint32_t abyte : 8;
    uint32_t signal : 3;
    uint32_t : 21;
} i2c_acqdata;

typedef struct [[gnu::aligned(4)]] {
    uint32_t txdata : 8;
    uint32_t : 24;
} i2c_txdata;

typedef struct [[gnu::aligned(4)]] {
    uint32_t host_timeout_ctrl : 20;
    uint32_t : 12;
} i2c_host_timeout_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 31;
    uint32_t en : 1;
} i2c_target_timeout_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 31;
    uint32_t en : 1;
} i2c_host_nack_handler_timeout;

typedef struct [[gnu::aligned(4)]] {
    uint32_t target_nack_count : 8;
    uint32_t : 24;
} i2c_target_nack_count;

typedef struct [[gnu::aligned(4)]] {
    uint32_t nbytes : 9;
    uint32_t : 22;
    uint32_t nack : 1;
} i2c_target_ack_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t acq_fifo_next_data : 8;
    uint32_t : 24;
} i2c_acq_fifo_next_data;

typedef enum [[clang::flag_enum]] i2c_controller_events : uint32_t {
    i2c_controller_events_nack = (1u << 0),
    i2c_controller_events_unhandled_nack_timeout = (1u << 1),
    i2c_controller_events_bus_timeout = (1u << 2),
    i2c_controller_events_arbitration_lost = (1u << 3),
} i2c_controller_events;

typedef enum [[clang::flag_enum]] i2c_target_events : uint32_t {
    i2c_target_events_tx_pending = (1u << 0),
    i2c_target_events_bus_timeout = (1u << 1),
    i2c_target_events_arbitration_lost = (1u << 2),
} i2c_target_events;

typedef volatile struct [[gnu::aligned(4)]] i2c_memory_layout {
    /* i2c.intr_state (0x0) */
    i2c_intr intr_state;

    /* i2c.intr_enable (0x4) */
    i2c_intr intr_enable;

    /* i2c.intr_test (0x8) */
    i2c_intr intr_test;

    /* i2c.alert_test (0xc) */
    i2c_alert_test alert_test;

    /* i2c.ctrl (0x10) */
    i2c_ctrl ctrl;

    /* i2c.status (0x14) */
    const i2c_status status;

    /* i2c.rdata (0x18) */
    const i2c_rdata rdata;

    /* i2c.fdata (0x1c) */
    i2c_fdata fdata;

    /* i2c.fifo_ctrl (0x20) */
    i2c_fifo_ctrl fifo_ctrl;

    /* i2c.host_fifo_config (0x24) */
    i2c_host_fifo_config host_fifo_config;

    /* i2c.target_fifo_config (0x28) */
    i2c_target_fifo_config target_fifo_config;

    /* i2c.host_fifo_status (0x2c) */
    const i2c_host_fifo_status host_fifo_status;

    /* i2c.target_fifo_status (0x30) */
    const i2c_target_fifo_status target_fifo_status;

    /* i2c.ovrd (0x34) */
    i2c_ovrd ovrd;

    /* i2c.val (0x38) */
    const i2c_val val;

    /* i2c.timing0 (0x3c) */
    i2c_timing0 timing0;

    /* i2c.timing1 (0x40) */
    i2c_timing1 timing1;

    /* i2c.timing2 (0x44) */
    i2c_timing2 timing2;

    /* i2c.timing3 (0x48) */
    i2c_timing3 timing3;

    /* i2c.timing4 (0x4c) */
    i2c_timing4 timing4;

    /* i2c.timeout_ctrl (0x50) */
    i2c_timeout_ctrl timeout_ctrl;

    /* i2c.target_id (0x54) */
    i2c_target_id target_id;

    /* i2c.acqdata (0x58) */
    const i2c_acqdata acqdata;

    /* i2c.txdata (0x5c) */
    i2c_txdata txdata;

    /* i2c.host_timeout_ctrl (0x60) */
    i2c_host_timeout_ctrl host_timeout_ctrl;

    /* i2c.target_timeout_ctrl (0x64) */
    i2c_target_timeout_ctrl target_timeout_ctrl;

    /* i2c.target_nack_count (0x68) */
    i2c_target_nack_count target_nack_count;

    /* i2c.target_ack_ctrl (0x6c) */
    i2c_target_ack_ctrl target_ack_ctrl;

    /* i2c.acq_fifo_next_data (0x70) */
    const i2c_acq_fifo_next_data acq_fifo_next_data;

    /* i2c.host_nack_handler_timeout (0x74) */
    i2c_host_nack_handler_timeout host_nack_handler_timeout;

    /* i2c.controller_events (0x78) */
    i2c_controller_events controller_events;

    /* i2c.target_events (0x7c) */
    i2c_target_events target_events;
} *i2c_t;

_Static_assert(__builtin_offsetof(struct i2c_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, ctrl) == 0x10ul,
               "incorrect register ctrl offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, status) == 0x14ul,
               "incorrect register status offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, rdata) == 0x18ul,
               "incorrect register rdata offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, fdata) == 0x1cul,
               "incorrect register fdata offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, fifo_ctrl) == 0x20ul,
               "incorrect register fifo_ctrl offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, host_fifo_config) == 0x24ul,
               "incorrect register host_fifo_config offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_fifo_config) == 0x28ul,
               "incorrect register target_fifo_config offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, host_fifo_status) == 0x2cul,
               "incorrect register host_fifo_status offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_fifo_status) == 0x30ul,
               "incorrect register target_fifo_status offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, ovrd) == 0x34ul,
               "incorrect register ovrd offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, val) == 0x38ul,
               "incorrect register val offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, timing0) == 0x3cul,
               "incorrect register timing0 offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, timing1) == 0x40ul,
               "incorrect register timing1 offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, timing2) == 0x44ul,
               "incorrect register timing2 offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, timing3) == 0x48ul,
               "incorrect register timing3 offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, timing4) == 0x4cul,
               "incorrect register timing4 offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, timeout_ctrl) == 0x50ul,
               "incorrect register timeout_ctrl offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_id) == 0x54ul,
               "incorrect register target_id offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, acqdata) == 0x58ul,
               "incorrect register acqdata offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, txdata) == 0x5cul,
               "incorrect register txdata offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, host_timeout_ctrl) == 0x60ul,
               "incorrect register host_timeout_ctrl offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_timeout_ctrl) == 0x64ul,
               "incorrect register target_timeout_ctrl offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_nack_count) == 0x68ul,
               "incorrect register target_nack_count offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_ack_ctrl) == 0x6cul,
               "incorrect register target_ack_ctrl offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, acq_fifo_next_data) == 0x70ul,
               "incorrect register acq_fifo_next_data offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, host_nack_handler_timeout) == 0x74ul,
               "incorrect register host_nack_handler_timeout offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, controller_events) == 0x78ul,
               "incorrect register controller_events offset");
_Static_assert(__builtin_offsetof(struct i2c_memory_layout, target_events) == 0x7cul,
               "incorrect register target_events offset");

_Static_assert(sizeof(i2c_intr) == sizeof(uint32_t),
               "register type i2c_intr is not register sized");
_Static_assert(sizeof(i2c_alert_test) == sizeof(uint32_t),
               "register type i2c_alert_test is not register sized");
_Static_assert(sizeof(i2c_ctrl) == sizeof(uint32_t),
               "register type i2c_ctrl is not register sized");
_Static_assert(sizeof(i2c_status) == sizeof(uint32_t),
               "register type i2c_status is not register sized");
_Static_assert(sizeof(i2c_rdata) == sizeof(uint32_t),
               "register type i2c_rdata is not register sized");
_Static_assert(sizeof(i2c_fdata) == sizeof(uint32_t),
               "register type i2c_fdata is not register sized");
_Static_assert(sizeof(i2c_fifo_ctrl) == sizeof(uint32_t),
               "register type i2c_fifo_ctrl is not register sized");
_Static_assert(sizeof(i2c_host_fifo_config) == sizeof(uint32_t),
               "register type i2c_host_fifo_config is not register sized");
_Static_assert(sizeof(i2c_target_fifo_config) == sizeof(uint32_t),
               "register type i2c_target_fifo_config is not register sized");
_Static_assert(sizeof(i2c_host_fifo_status) == sizeof(uint32_t),
               "register type i2c_host_fifo_status is not register sized");
_Static_assert(sizeof(i2c_target_fifo_status) == sizeof(uint32_t),
               "register type i2c_target_fifo_status is not register sized");
_Static_assert(sizeof(i2c_ovrd) == sizeof(uint32_t),
               "register type i2c_ovrd is not register sized");
_Static_assert(sizeof(i2c_val) == sizeof(uint32_t), "register type i2c_val is not register sized");
_Static_assert(sizeof(i2c_timing0) == sizeof(uint32_t),
               "register type i2c_timing0 is not register sized");
_Static_assert(sizeof(i2c_timing1) == sizeof(uint32_t),
               "register type i2c_timing1 is not register sized");
_Static_assert(sizeof(i2c_timing2) == sizeof(uint32_t),
               "register type i2c_timing2 is not register sized");
_Static_assert(sizeof(i2c_timing3) == sizeof(uint32_t),
               "register type i2c_timing3 is not register sized");
_Static_assert(sizeof(i2c_timing4) == sizeof(uint32_t),
               "register type i2c_timing4 is not register sized");
_Static_assert(sizeof(i2c_timeout_ctrl) == sizeof(uint32_t),
               "register type i2c_timeout_ctrl is not register sized");
_Static_assert(sizeof(i2c_target_id) == sizeof(uint32_t),
               "register type i2c_target_id is not register sized");
_Static_assert(sizeof(i2c_acqdata) == sizeof(uint32_t),
               "register type i2c_acqdata is not register sized");
_Static_assert(sizeof(i2c_txdata) == sizeof(uint32_t),
               "register type i2c_txdata is not register sized");
_Static_assert(sizeof(i2c_host_timeout_ctrl) == sizeof(uint32_t),
               "register type i2c_host_timeout_ctrl is not register sized");
_Static_assert(sizeof(i2c_target_timeout_ctrl) == sizeof(uint32_t),
               "register type i2c_target_timeout_ctrl is not register sized");
_Static_assert(sizeof(i2c_host_nack_handler_timeout) == sizeof(uint32_t),
               "register type i2c_host_nack_handler_timeout is not register sized");
_Static_assert(sizeof(i2c_target_nack_count) == sizeof(uint32_t),
               "register type i2c_target_nack_count is not register sized");
_Static_assert(sizeof(i2c_target_ack_ctrl) == sizeof(uint32_t),
               "register type i2c_target_ack_ctrl is not register sized");
_Static_assert(sizeof(i2c_acq_fifo_next_data) == sizeof(uint32_t),
               "register type i2c_acq_fifo_next_data is not register sized");
_Static_assert(sizeof(i2c_controller_events) == sizeof(uint32_t),
               "register type i2c_controller_events is not register sized");
_Static_assert(sizeof(i2c_target_events) == sizeof(uint32_t),
               "register type i2c_target_events is not register sized");
