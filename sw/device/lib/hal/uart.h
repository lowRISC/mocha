// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/uart.h"
#include <stdbool.h>
#include <stdint.h>

#define BAUD_RATE (1000000u)

/* initialisation */
void uart_init(uart_t uart);

/* interrupts */
uart_intr uart_interrupt_enable_read(uart_t uart);
void uart_interrupt_enable_write(uart_t uart, uart_intr intrs);
void uart_interrupt_enable_set(uart_t uart, uart_intr intrs);
void uart_interrupt_enable_clear(uart_t uart, uart_intr intrs);
void uart_interrupt_force(uart_t uart, uart_intr intrs);
void uart_interrupt_clear(uart_t uart, uart_intr intrs);
bool uart_interrupt_all_pending(uart_t uart, uart_intr intrs);
bool uart_interrupt_any_pending(uart_t uart, uart_intr intrs);

void uart_loopback_set(uart_t uart, bool system_enable, bool line_enable);
char uart_in(uart_t uart);
void uart_out(uart_t uart, char ch);
void uart_putchar(uart_t uart, char ch);
void uart_puts(uart_t uart, const char *str);
