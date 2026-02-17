// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdint.h>

void uart_init(uart_t uart)
{
    uart_ctrl ctrl = volatile_read(uart->ctrl);
    ctrl.tx = true;
    ctrl.rx = true;
    ctrl.nco = (((uint64_t)BAUD_RATE << 20) / SYSCLK_FREQ);
    volatile_write(uart->ctrl, ctrl);
}

uart_intr uart_interrupt_enable_get(uart_t uart)
{
    return volatile_read(uart->intr_enable);
}

void uart_interrupt_enable_set(uart_t uart, uart_intr intrs)
{
    volatile_write(uart->intr_enable, intrs);
}

void uart_interrupt_enable(uart_t uart, uart_intr intrs)
{
    uart_intr intr_enable = volatile_read(uart->intr_enable);
    intr_enable |= intrs;
    volatile_write(uart->intr_enable, intr_enable);
}

void uart_interrupt_disable(uart_t uart, uart_intr intrs)
{
    uart_intr intr_enable = volatile_read(uart->intr_enable);
    intr_enable &= ~intrs;
    volatile_write(uart->intr_enable, intr_enable);
}

void uart_interrupt_disable_all(uart_t uart)
{
    volatile_write(uart->intr_enable, 0u);
}

void uart_interrupt_force(uart_t uart, uart_intr intrs)
{
    volatile_write(uart->intr_test, intrs);
}

void uart_interrupt_clear(uart_t uart, uart_intr intrs)
{
    volatile_write(uart->intr_state, intrs);
}

bool uart_interrupt_all_pending(uart_t uart, uart_intr intrs)
{
    return (volatile_read(uart->intr_state) & intrs) == intrs;
}

bool uart_interrupt_any_pending(uart_t uart, uart_intr intrs)
{
    return (volatile_read(uart->intr_state) & intrs) != 0u;
}

void uart_loopback_set(uart_t uart, bool system_enable, bool line_enable)
{
    uart_ctrl ctrl = volatile_read(uart->ctrl);
    ctrl.slpbk = system_enable;
    ctrl.llpbk = line_enable;
    volatile_write(uart->ctrl, ctrl);
}

char uart_in(uart_t uart)
{
    uart_status status;
    do {
        status = volatile_read(uart->status);
    } while (status & uart_status_rxempty);

    uart_rdata rdata = volatile_read(uart->rdata);
    return (char)(rdata.rdata);
}

void uart_out(uart_t uart, char ch)
{
    uart_status status;
    do {
        status = volatile_read(uart->status);
    } while (status & uart_status_txfull);

    uart_wdata wdata = {
        .wdata = ch,
    };
    volatile_write(uart->wdata, wdata);
}

void uart_putchar(uart_t uart, char ch)
{
    if (ch == '\n') {
        uart_out(uart, '\r');
    }
    uart_out(uart, ch);
}

void uart_puts(uart_t uart, const char *str)
{
    while (*str != '\0') {
        uart_putchar(uart, *str++);
    }
}
