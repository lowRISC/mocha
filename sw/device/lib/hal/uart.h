// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define UART_INTR_STATE_REG  (0x0)
#define UART_INTR_ENABLE_REG (0x4)
#define UART_INTR_TEST_REG   (0x8)

#define UART_INTR_TX_WATERMARK  (0)
#define UART_INTR_RX_WATERMARK  (1)
#define UART_INTR_TX_DONE       (2)
#define UART_INTR_RX_OVERFLOW   (3)
#define UART_INTR_RX_FRAME_ERR  (4)
#define UART_INTR_RX_BREAK_ERR  (5)
#define UART_INTR_RX_TIMEOUT    (6)
#define UART_INTR_RX_PARITY_ERR (7)
#define UART_INTR_TX_EMPTY      (8)
#define UART_MAX_INTR           (8)

#define UART_CTRL_REG   (0x10)
#define UART_CTRL_SLPBK (4)
#define UART_CTRL_LLPBK (5)

#define UART_STATUS_REG      (0x14)
#define UART_STATUS_RX_EMPTY (0x20)
#define UART_STATUS_TX_FULL  (2)

#define UART_RX_REG (0x18)
#define UART_TX_REG (0x1C)

#define BAUD_RATE (1000000)

#define UART_EOF -1

typedef void *uart_t;

#define UART_FROM_BASE_ADDR(addr) ((uart_t)(addr))

void uart_interrupt_disable_all(uart_t uart);
void uart_interrupt_enable(uart_t uart, uint8_t intr_id);
void uart_interrupt_disable(uart_t uart, uint8_t intr_id);
void uart_interrupt_trigger(uart_t uart, uint8_t intr_id);
void uart_interrupt_clear(uart_t uart, uint8_t intr_id);
int uart_init(uart_t uart);
void uart_enable_rx_int(void);
int uart_in(uart_t uart);
void uart_out(uart_t uart, char c);
void uart_loopback(uart_t uart, bool enable);
int uart_putchar(uart_t uart, int c);
int uart_puts(uart_t uart, const char *str);
