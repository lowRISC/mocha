// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdint.h>

void uart_init(uart_t uart)
{
    // Enable divisor latch access
    uart_lcr lcr = VOLATILE_READ(uart->lcr);
    lcr.dlab = 1;
    VOLATILE_WRITE(uart->lcr, lcr);

    // Write divisor latch
    uart_dl_t uart_dl = (uart_dl_t)uart;
    uint16_t dl = system_clock_frequency / ((uint64_t)BAUD_RATE << 4);
    uart_dll dll = {
        .dll = dl & 0xFF,
    };
    VOLATILE_WRITE(uart_dl->dll, dll);
    uart_dlm dlm = {
        .dlm = dl >> 8,
    };
    VOLATILE_WRITE(uart_dl->dlm, dlm);

    // Disable divisor latch access
    lcr.dlab = 0;
    VOLATILE_WRITE(uart->lcr, lcr);
}

uart_ier uart_interrupt_enable_read(uart_t uart)
{
    return VOLATILE_READ(uart->ier);
}

void uart_interrupt_enable_write(uart_t uart, uart_ier intrs)
{
    VOLATILE_WRITE(uart->ier, intrs);
}

void uart_interrupt_enable_set(uart_t uart, uart_ier intrs)
{
    uart_ier ier = VOLATILE_READ(uart->ier);
    ier |= intrs;
    VOLATILE_WRITE(uart->ier, ier);
}

void uart_interrupt_enable_clear(uart_t uart, uart_ier intrs)
{
    uart_ier ier = VOLATILE_READ(uart->ier);
    ier &= ~intrs;
    VOLATILE_WRITE(uart->ier, ier);
}

bool uart_interrupt_is_pending(uart_t uart)
{
    uart_iir iir = VOLATILE_READ(uart->iir);
    return !iir.intr_pending;
}

uart_intr_id uart_pending_interrupt_read(uart_t uart)
{
    uart_iir iir = VOLATILE_READ(uart->iir);
    return (uart_intr_id)iir.intr_id;
}

bool uart_line_status_any(uart_t uart, uart_lsr lsr)
{
    // This will clear any receive error in the LSR as a side effect
    return (VOLATILE_READ(uart->lsr) & lsr) != 0u;
}

bool uart_line_status_all(uart_t uart, uart_lsr lsr)
{
    // This will clear any receive error in the LSR as a side effect
    return (VOLATILE_READ(uart->lsr) & lsr) == lsr;
}

void uart_loopback_set(uart_t uart, bool system_enable)
{
    uart_mcr mcr = VOLATILE_READ(uart->mcr);
    mcr.loop = system_enable;
    VOLATILE_WRITE(uart->mcr, mcr);
}

char uart_in(uart_t uart)
{
    // Wait until there is received data
    uart_wait_for(uart, uart_lsr_dr);

    // Read from Rx FIFO
    uart_rbr rbr = VOLATILE_READ(uart->rbr);
    return (char)(rbr.rbr);
}

void uart_out(uart_t uart, char ch)
{
    // Wait until THR is empty
    uart_wait_for(uart, uart_lsr_thre);

    // Push to Tx FIFO
    uart_wo_t uart_wo = (uart_wo_t)uart;
    uart_thr thr = { .thr = ch };
    VOLATILE_WRITE(uart_wo->thr, thr);
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
