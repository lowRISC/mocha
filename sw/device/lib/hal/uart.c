// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdint.h>

void uart_interrupt_disable_all(uart_t uart)
{
    DEV_WRITE(uart + UART_INTR_ENABLE_REG, 0);
}

void uart_interrupt_enable(uart_t uart, uint8_t intr_id)
{
    if (intr_id <= UART_MAX_INTR) {
        DEV_WRITE(uart + UART_INTR_ENABLE_REG,
                  DEV_READ(uart + UART_INTR_ENABLE_REG) | (1 << intr_id));
    }
}

void uart_interrupt_disable(uart_t uart, uint8_t intr_id)
{
    if (intr_id <= UART_MAX_INTR) {
        DEV_WRITE(uart + UART_INTR_ENABLE_REG,
                  DEV_READ(uart + UART_INTR_ENABLE_REG) & ~(1 << intr_id));
    }
}

void uart_interrupt_trigger(uart_t uart, uint8_t intr_id)
{
    if (intr_id <= UART_MAX_INTR) {
        DEV_WRITE(uart + UART_INTR_TEST_REG, 1 << intr_id);
    }
}

void uart_interrupt_clear(uart_t uart, uint8_t intr_id)
{
    if (intr_id <= UART_MAX_INTR) {
        DEV_WRITE(uart + UART_INTR_STATE_REG, 1 << intr_id);
    }
}

int uart_init(uart_t uart)
{
    // NCO = 2^20 * baud rate / cpu frequency
    uint32_t nco = (uint32_t)(((uint64_t)BAUD_RATE << 20) / SYSCLK_FREQ);

    DEV_WRITE(uart + UART_CTRL_REG, (nco << 16) | 0x3U);

    return 0;
}

int uart_in(uart_t uart)
{
    int res = UART_EOF;

    if (!(DEV_READ(uart + UART_STATUS_REG) & UART_STATUS_RX_EMPTY)) {
        res = DEV_READ(uart + UART_RX_REG);
    }

    return res;
}

void uart_out(uart_t uart, char c)
{
    while (DEV_READ(uart + UART_STATUS_REG) & UART_STATUS_TX_FULL) {
    }

    DEV_WRITE(uart + UART_TX_REG, c);
}

void uart_loopback(uart_t uart, bool enable)
{
    uint32_t reg = DEV_READ(uart + UART_CTRL_REG);
    uint32_t mask = 0x01 << UART_CTRL_SLPBK | 0x01 << UART_CTRL_LLPBK;
    reg &= ~mask;
    reg |= (enable << UART_CTRL_SLPBK | enable << UART_CTRL_LLPBK);
    DEV_WRITE(uart + UART_CTRL_REG, reg);
}

int uart_putchar(uart_t uart, int c)
{
    if (c == '\n') {
        uart_out(uart, '\r');
    }

    uart_out(uart, c);
    return c;
}

int uart_puts(uart_t uart, const char *str)
{
    while (*str) {
        uart_putchar(uart, *str++);
    }
    return 0;
}

void uart_put_uint32_hex(uart_t uart, uint32_t num)
{
    uint32_t current_num = num;
    for (uint32_t i = 0; i < ((uint32_t)sizeof(uint32_t) * 8 / 4); ++i) {
        switch ((current_num >> (sizeof(uint32_t) * 8 - 4)) & 0xF) {
        case 0x0:
            uart_out(uart, '0');
            break;
        case 0x1:
            uart_out(uart, '1');
            break;
        case 0x2:
            uart_out(uart, '2');
            break;
        case 0x3:
            uart_out(uart, '3');
            break;
        case 0x4:
            uart_out(uart, '4');
            break;
        case 0x5:
            uart_out(uart, '5');
            break;
        case 0x6:
            uart_out(uart, '6');
            break;
        case 0x7:
            uart_out(uart, '7');
            break;
        case 0x8:
            uart_out(uart, '8');
            break;
        case 0x9:
            uart_out(uart, '9');
            break;
        case 0xA:
            uart_out(uart, 'A');
            break;
        case 0xB:
            uart_out(uart, 'B');
            break;
        case 0xC:
            uart_out(uart, 'C');
            break;
        case 0xD:
            uart_out(uart, 'D');
            break;
        case 0xE:
            uart_out(uart, 'E');
            break;
        case 0xF:
            uart_out(uart, 'F');
            break;
        default:
            uart_out(uart, '?');
            break;
        }
        current_num = current_num << 4;
    }
}
