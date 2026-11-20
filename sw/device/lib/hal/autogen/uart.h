// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Auto-generated: 'util/rdlgenerator.py gen-device-headers build/rdl/rdl.json sw/device/lib/hal/autogen'

#pragma once

#include <stdbool.h>
#include <stdint.h>

typedef struct [[gnu::aligned(4)]] {
    uint32_t rbr : 8;
    uint32_t : 24;
} uart_rbr;

typedef enum [[clang::flag_enum]] uart_ier : uint32_t {
    uart_ier_none = 0,
    uart_ier_erbfi = (1u << 0),
    uart_ier_etbei = (1u << 1),
    uart_ier_elsi = (1u << 2),
    uart_ier_edssi = (1u << 3),
} uart_ier;

typedef struct [[gnu::aligned(4)]] {
    uint32_t intr_pending : 1;
    uint32_t intr_id : 3;
    uint32_t : 2;
    uint32_t fifo_en : 2;
    uint32_t : 24;
} uart_iir;

typedef struct [[gnu::aligned(4)]] {
    uint32_t wls : 2;
    uint32_t stb : 1;
    uint32_t pen : 1;
    uint32_t eps : 1;
    uint32_t stick_parity : 1;
    uint32_t break_ctrl : 1;
    uint32_t dlab : 1;
    uint32_t : 24;
} uart_lcr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t dtr : 1;
    uint32_t rts : 1;
    uint32_t out : 2;
    uint32_t loop : 1;
    uint32_t : 27;
} uart_mcr;

typedef enum [[clang::flag_enum]] uart_lsr : uint32_t {
    uart_lsr_none = 0,
    uart_lsr_dr = (1u << 0),
    uart_lsr_oe = (1u << 1),
    uart_lsr_pe = (1u << 2),
    uart_lsr_fe = (1u << 3),
    uart_lsr_bi = (1u << 4),
    uart_lsr_thre = (1u << 5),
    uart_lsr_temt = (1u << 6),
    uart_lsr_rcvr_fifo_error = (1u << 7),
} uart_lsr;

typedef enum [[clang::flag_enum]] uart_msr : uint32_t {
    uart_msr_none = 0,
    uart_msr_dcts = (1u << 0),
    uart_msr_ddsr = (1u << 1),
    uart_msr_teri = (1u << 2),
    uart_msr_ddcd = (1u << 3),
    uart_msr_cts = (1u << 4),
    uart_msr_dsr = (1u << 5),
    uart_msr_ri = (1u << 6),
    uart_msr_dcd = (1u << 7),
} uart_msr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t scr : 8;
    uint32_t : 24;
} uart_scr;

typedef volatile struct [[gnu::aligned(4)]] uart_memory_layout {
    /* uart.rbr (0x0) */
    const uart_rbr rbr;

    /* uart.ier (0x4) */
    uart_ier ier;

    /* uart.iir (0x8) */
    const uart_iir iir;

    /* uart.lcr (0xc) */
    uart_lcr lcr;

    /* uart.mcr (0x10) */
    uart_mcr mcr;

    /* uart.lsr (0x14) */
    uart_lsr lsr;

    /* uart.msr (0x18) */
    const uart_msr msr;

    /* uart.scr (0x1c) */
    uart_scr scr;
} *uart_t;

_Static_assert(__builtin_offsetof(struct uart_memory_layout, rbr) == 0x0ul,
               "incorrect register rbr offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, ier) == 0x4ul,
               "incorrect register ier offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, iir) == 0x8ul,
               "incorrect register iir offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, lcr) == 0xcul,
               "incorrect register lcr offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, mcr) == 0x10ul,
               "incorrect register mcr offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, lsr) == 0x14ul,
               "incorrect register lsr offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, msr) == 0x18ul,
               "incorrect register msr offset");
_Static_assert(__builtin_offsetof(struct uart_memory_layout, scr) == 0x1cul,
               "incorrect register scr offset");

_Static_assert(sizeof(uart_rbr) == sizeof(uint32_t),
               "register type uart_rbr is not register sized");
_Static_assert(sizeof(uart_ier) == sizeof(uint32_t),
               "register type uart_ier is not register sized");
_Static_assert(sizeof(uart_iir) == sizeof(uint32_t),
               "register type uart_iir is not register sized");
_Static_assert(sizeof(uart_lcr) == sizeof(uint32_t),
               "register type uart_lcr is not register sized");
_Static_assert(sizeof(uart_mcr) == sizeof(uint32_t),
               "register type uart_mcr is not register sized");
_Static_assert(sizeof(uart_lsr) == sizeof(uint32_t),
               "register type uart_lsr is not register sized");
_Static_assert(sizeof(uart_msr) == sizeof(uint32_t),
               "register type uart_msr is not register sized");
_Static_assert(sizeof(uart_scr) == sizeof(uint32_t),
               "register type uart_scr is not register sized");
