// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#define UART_BASE (0x80000000)

#define UART_CTRL_REG (0x10)
#define UART_STATUS_REG (0x14)
#define UART_RX_REG (0x18)
#define UART_TX_REG (0x1C)

#define UART_STATUS_RX_EMPTY (0x20)
#define UART_STATUS_TX_FULL (2)

#define UART_EOF (-1)

#define BAUD_RATE (921600)
#define SYSCLK_FREQ (50000000)

#include <stdint.h>

#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr) (*((volatile uint32_t *)(addr)))

typedef void* uart_t;

int uart_init(uart_t uart) {
  // NCO = 2^20 * baud rate / cpu frequency
  uint32_t nco = (uint32_t)(((uint64_t)BAUD_RATE << 20) / SYSCLK_FREQ);

  DEV_WRITE(uart + UART_CTRL_REG, (nco << 16) | 0x3U);

  return 0;
}

int uart_in(uart_t uart) {
  int res = UART_EOF;

  if (!(DEV_READ(uart + UART_STATUS_REG) & UART_STATUS_RX_EMPTY)) {
    res = DEV_READ(uart + UART_RX_REG);
  }

  return res;
}

void uart_out(uart_t uart, char c) {
  while (DEV_READ(uart + UART_STATUS_REG) & UART_STATUS_TX_FULL) {
  }

  DEV_WRITE(uart + UART_TX_REG, c);
}

int putchar(int c) {
  if (c == '\n') {
    uart_out((uart_t) UART_BASE, '\r');
  }

  uart_out((uart_t) UART_BASE, c);
  return c;
}

int puts(const char* str) {
  while (*str) {
    putchar(*str++);
  }
  return 0;
}

int main(void) {
  uart_init((uart_t) UART_BASE);

  puts("Hello CHERI Mocha!\n");

  while(1) {
  }

  return 0;
}
