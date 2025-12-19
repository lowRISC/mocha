// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include <stdbool.h>

#define UART_CTRL_REG   (0x10)
#define UART_CTRL_SLPBK (4)
#define UART_CTRL_LLPBK (5)

#define UART_STATUS_REG      (0x14)
#define UART_STATUS_RX_EMPTY (0x20)
#define UART_STATUS_TX_FULL  (2)

#define UART_RX_REG (0x18)
#define UART_TX_REG (0x1C)

#define BAUD_RATE (921600)

#define UART_EOF -1

typedef void *uart_t;

#define UART_FROM_BASE_ADDR(addr) ((uart_t)(addr))

int uart_init(uart_t uart);
void uart_enable_rx_int(void);
int uart_in(uart_t uart);
void uart_out(uart_t uart, char c);
void uart_loopback(uart_t uart, bool enable);
int uart_putchar(uart_t uart, int c);
int uart_puts(uart_t uart, const char *str);
