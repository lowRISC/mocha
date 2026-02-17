// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef enum [[clang::flag_enum]] uart_intr : uint32_t {
    uart_intr_tx_watermark = (1u << 0),
    uart_intr_rx_watermark = (1u << 1),
    uart_intr_tx_done = (1u << 2),
    uart_intr_rx_overflow = (1u << 3),
    uart_intr_rx_frame_err = (1u << 4),
    uart_intr_rx_break_err = (1u << 5),
    uart_intr_rx_timeout = (1u << 6),
    uart_intr_rx_parity_err = (1u << 7),
    uart_intr_tx_empty = (1u << 8),
} uart_intr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fatal_fault : 1;
    uint32_t : 31;
} uart_alert_test;

typedef struct [[gnu::aligned(4)]] {
    uint32_t tx : 1;
    uint32_t rx : 1;
    uint32_t nf : 1;
    uint32_t : 1;
    uint32_t slpbk : 1;
    uint32_t llpbk : 1;
    uint32_t parity_en : 1;
    uint32_t parity_odd : 1;
    uint32_t rxblvl : 2;
    uint32_t : 6;
    uint32_t nco : 16;
} uart_ctrl;

typedef enum [[clang::flag_enum]] uart_status : uint32_t {
    uart_status_txfull = (1u << 0),
    uart_status_rxfull = (1u << 1),
    uart_status_txempty = (1u << 2),
    uart_status_txidle = (1u << 3),
    uart_status_rxidle = (1u << 4),
    uart_status_rxempty = (1u << 5),
} uart_status;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rdata : 8;
    uint32_t : 24;
} uart_rdata;

typedef struct [[gnu::aligned(4)]] {
    uint32_t wdata : 8;
    uint32_t : 24;
} uart_wdata;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rxrst : 1;
    uint32_t txrst : 1;
    uint32_t rxilvl : 3;
    uint32_t txilvl : 3;
    uint32_t : 24;
} uart_fifo_ctrl;

typedef struct [[gnu::aligned(4)]] {
    uint32_t txlvl : 8;
    uint32_t : 8;
    uint32_t rxlvl : 8;
    uint32_t : 8;
} uart_fifo_status;

typedef enum [[clang::flag_enum]] uart_ovrd : uint32_t {
    uart_ovrd_txen = (1u << 0),
    uart_ovrd_txval = (1u << 1),
} uart_ovrd;

typedef struct [[gnu::aligned(4)]] {
    uint32_t rx : 16;
    uint32_t : 16;
} uart_val;

typedef struct [[gnu::aligned(4)]] {
    uint32_t val : 24;
    uint32_t : 7;
    uint32_t en : 1;
} uart_timeout_ctrl;

typedef volatile struct [[gnu::aligned(4)]] uart_memory_layout {
    /* uart.intr_state (0x0) */
    uart_intr intr_state;

    /* uart.intr_enable (0x4) */
    uart_intr intr_enable;

    /* uart.intr_test (0x8) */
    uart_intr intr_test;

    /* uart.alert_test (0xc) */
    uart_alert_test alert_test;

    /* uart.ctrl (0x10) */
    uart_ctrl ctrl;

    /* uart.status (0x14) */
    const uart_status status;

    /* uart.rdata (0x18) */
    const uart_rdata rdata;

    /* uart.wdata (0x1c) */
    uart_wdata wdata;

    /* uart.fifo_ctrl (0x20) */
    uart_fifo_ctrl fifo_ctrl;

    /* uart.fifo_status (0x24) */
    const uart_fifo_status fifo_status;

    /* uart.ovrd (0x28) */
    uart_ovrd ovrd;

    /* uart.val (0x2c) */
    const uart_val val;

    /* uart.timeout_ctrl (0x30) */
    uart_timeout_ctrl timeout_ctrl;
} *uart_t;

_Static_assert(__builtin_offsetof(struct uart_memory_layout, intr_state) == 0x0ul,
               "incorrect register intr_state offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, intr_enable) == 0x4ul,
               "incorrect register intr_enable offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, intr_test) == 0x8ul,
               "incorrect register intr_test offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, alert_test) == 0xcul,
               "incorrect register alert_test offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, ctrl) == 0x10ul,
               "incorrect register ctrl offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, status) == 0x14ul,
               "incorrect register status offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, rdata) == 0x18ul,
               "incorrect register rdata offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, wdata) == 0x1cul,
               "incorrect register wdata offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, fifo_ctrl) == 0x20ul,
               "incorrect register fifo_ctrl offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, fifo_status) == 0x24ul,
               "incorrect register fifo_status offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, ovrd) == 0x28ul,
               "incorrect register ovrd offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, val) == 0x2cul,
               "incorrect register val offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, timeout_ctrl) == 0x30ul,
               "incorrect register timeout_ctrl offset");

_Static_assert(sizeof(uart_intr) == sizeof(uint32_t),
               "register type uart_intr is not register sized");
_Static_assert(sizeof(uart_alert_test) == sizeof(uint32_t),
               "register type uart_alert_test is not register sized");
_Static_assert(sizeof(uart_ctrl) == sizeof(uint32_t),
               "register type uart_ctrl is not register sized");
_Static_assert(sizeof(uart_status) == sizeof(uint32_t),
               "register type uart_status is not register sized");
_Static_assert(sizeof(uart_rdata) == sizeof(uint32_t),
               "register type uart_rdata is not register sized");
_Static_assert(sizeof(uart_wdata) == sizeof(uint32_t),
               "register type uart_wdata is not register sized");
_Static_assert(sizeof(uart_fifo_ctrl) == sizeof(uint32_t),
               "register type uart_fifo_ctrl is not register sized");
_Static_assert(sizeof(uart_fifo_status) == sizeof(uint32_t),
               "register type uart_fifo_status is not register sized");
_Static_assert(sizeof(uart_ovrd) == sizeof(uint32_t),
               "register type uart_ovrd is not register sized");
_Static_assert(sizeof(uart_val) == sizeof(uint32_t),
               "register type uart_val is not register sized");
_Static_assert(sizeof(uart_timeout_ctrl) == sizeof(uint32_t),
               "register type uart_timeout_ctrl is not register sized");
