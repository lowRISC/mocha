// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/uart.h"
#include <stdbool.h>
#include <stdint.h>

#define BAUD_RATE (1000000u)


/* Interrupt ID enum from IIR */
typedef enum uart_intr_id : uint32_t {
    uart_intr_id_receiver_line_status = 0b011,
    uart_intr_id_received_data_available = 0b010,
    uart_intr_id_character_timeout_indication = 0b110,
    uart_intr_id_transmitter_holding_register_empty = 0b001,
    uart_intr_id_modem_status = 0b000,
} uart_intr_id;


/* Write-only register types */
typedef struct [[gnu::aligned(4)]] {
    uint32_t thr : 8;
    uint32_t : 24;
} uart_thr;

typedef struct [[gnu::aligned(4)]] {
    uint32_t fifo_en : 1;
    uint32_t rcvr_fifo_reset : 1;
    uint32_t xmit_fifo_reset : 1;
    uint32_t dma_mode_sel : 1;
    uint32_t : 2;
    uint32_t uart_rcvr_trigger : 2;
    uint32_t : 24;
} uart_fcr;


/* Divisor latch register types */
typedef struct [[gnu::aligned(4)]] {
    uint32_t dll : 8;
    uint32_t : 24;
} uart_dll;

typedef struct [[gnu::aligned(4)]] {
    uint32_t dlm : 8;
    uint32_t : 24;
} uart_dlm;


/* Write-only memory layout with DLAB=0 */
typedef volatile struct [[gnu::aligned(4)]] uart_wo_memory_layout {
    /* uart.thr (0x0) */
    uart_thr thr;

    const uint8_t __reserved1[0x8 - 0x4];

    /* uart.fcr (0x8) */
    uart_fcr fcr;
} *uart_wo_t;


/* Divisor latch memory layout with DLAB=1 */
typedef volatile struct [[gnu::aligned(4)]] uart_dl_memory_layout {
    /* uart.dll (0x0) */
    uart_dll dll;

    /* uart.dlm (0x4) */
    uart_dlm dlm;
} *uart_dl_t;


/* initialisation */
void uart_init(uart_t uart);

/* interrupts */
uart_ier uart_interrupt_enable_read(uart_t uart);
void uart_interrupt_enable_write(uart_t uart, uart_ier intrs);
void uart_interrupt_enable_set(uart_t uart, uart_ier intrs);
void uart_interrupt_enable_clear(uart_t uart, uart_ier intrs);
bool uart_interrupt_is_pending(uart_t uart);
uart_intr_id uart_pending_interrupt_read(uart_t uart);
bool uart_line_status_any(uart_t uart, uart_lsr lsr);
bool uart_line_status_all(uart_t uart, uart_lsr lsr);

static inline void uart_wait_for(uart_t uart, uart_lsr lsr)
{
    while (!uart_line_status_all(uart, lsr)) {
    };
}

void uart_loopback_set(uart_t uart, bool system_enable);
char uart_in(uart_t uart);
void uart_out(uart_t uart, char ch);
void uart_putchar(uart_t uart, char ch);
void uart_puts(uart_t uart, const char *str);
