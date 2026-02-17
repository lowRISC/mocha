// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdint.h>

void uart_init(uart_t uart)
{
    uart_ctrl ctrl = VOLATILE_READ(uart->ctrl);
    ctrl.tx = true;
    ctrl.rx = true;
    ctrl.nco = (((uint64_t)BAUD_RATE << 20) / system_clock_frequency);
    VOLATILE_WRITE(uart->ctrl, ctrl);
}

uart_intr uart_interrupt_enable_read(uart_t uart)
{
    return VOLATILE_READ(uart->intr_enable);
}

void uart_interrupt_enable_write(uart_t uart, uart_intr intrs)
{
    VOLATILE_WRITE(uart->intr_enable, intrs);
}

void uart_interrupt_enable_set(uart_t uart, uart_intr intrs)
{
    uart_intr intr_enable = VOLATILE_READ(uart->intr_enable);
    intr_enable |= intrs;
    VOLATILE_WRITE(uart->intr_enable, intr_enable);
}

void uart_interrupt_enable_clear(uart_t uart, uart_intr intrs)
{
    uart_intr intr_enable = VOLATILE_READ(uart->intr_enable);
    intr_enable &= ~intrs;
    VOLATILE_WRITE(uart->intr_enable, intr_enable);
}

void uart_interrupt_force(uart_t uart, uart_intr intrs)
{
    VOLATILE_WRITE(uart->intr_test, intrs);
}

void uart_interrupt_clear(uart_t uart, uart_intr intrs)
{
    VOLATILE_WRITE(uart->intr_state, intrs);
}

bool uart_interrupt_all_pending(uart_t uart, uart_intr intrs)
{
    return (VOLATILE_READ(uart->intr_state) & intrs) == intrs;
}

bool uart_interrupt_any_pending(uart_t uart, uart_intr intrs)
{
    return (VOLATILE_READ(uart->intr_state) & intrs) != 0u;
}

void uart_loopback_set(uart_t uart, bool system_enable, bool line_enable)
{
    uart_ctrl ctrl = VOLATILE_READ(uart->ctrl);
    ctrl.slpbk = system_enable;
    ctrl.llpbk = line_enable;
    VOLATILE_WRITE(uart->ctrl, ctrl);
}

char uart_in(uart_t uart)
{
    uart_status status;
    do {
        status = VOLATILE_READ(uart->status);
    } while (status & uart_status_rxempty);

    uart_rdata rdata = VOLATILE_READ(uart->rdata);
    return (char)(rdata.rdata);
}

void uart_out(uart_t uart, char ch)
{
    uart_status status;
    do {
        status = VOLATILE_READ(uart->status);
    } while (status & uart_status_txfull);

    uart_wdata wdata = {
        .wdata = ch,
    };
    VOLATILE_WRITE(uart->wdata, wdata);
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
