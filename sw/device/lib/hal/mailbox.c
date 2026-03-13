// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mailbox.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

void mailbox_write(mailbox_t mailbox, uint64_t value)
{
    DEV_WRITE64(mailbox + MAILBOX_MBOXW, value);
}

uint64_t mailbox_read(mailbox_t mailbox)
{
    return DEV_READ64(mailbox + MAILBOX_MBOXR);
}

bool mailbox_empty(mailbox_t mailbox)
{
    return (DEV_READ64(mailbox + MAILBOX_STATUS) & MAILBOX_STATUS_EMPTY_MASK) >>
           MAILBOX_STATUS_EMPTY_OFFSET;
}

bool mailbox_full(mailbox_t mailbox)
{
    return (DEV_READ64(mailbox + MAILBOX_STATUS) & MAILBOX_STATUS_FULL_MASK) >>
           MAILBOX_STATUS_FULL_OFFSET;
}

bool mailbox_get_r_error(mailbox_t mailbox)
{
    return (DEV_READ64(mailbox + MAILBOX_ERROR) & MAILBOX_ERROR_R_ERR_MASK) >>
           MAILBOX_ERROR_R_ERR_OFFSET;
}

bool mailbox_get_w_error(mailbox_t mailbox)
{
    return (DEV_READ64(mailbox + MAILBOX_ERROR) & MAILBOX_ERROR_W_ERR_MASK) >>
           MAILBOX_ERROR_W_ERR_OFFSET;
}

void mailbox_set_thresholds(mailbox_t mailbox, uint8_t write_threshold, uint8_t read_threshold)
{
    DEV_WRITE64(mailbox + MAILBOX_WIRQT, (uint64_t)write_threshold);
    DEV_WRITE64(mailbox + MAILBOX_RIRQT, (uint64_t)read_threshold);
}

void mailbox_set_irq(mailbox_t mailbox, bool err_irq, bool r_thr_irq, bool w_thr_irq)
{
    uint64_t ctrl_val = 0;
    ctrl_val |= w_thr_irq << MAILBOX_IRQ_WTIRQ_OFFSET;
    ctrl_val |= r_thr_irq << MAILBOX_IRQ_RTIRQ_OFFSET;
    ctrl_val |= err_irq << MAILBOX_IRQ_EIRQ_OFFSET;
    DEV_WRITE64(mailbox + MAILBOX_IRQEN, ctrl_val);
}

void mailbox_ack_irq(mailbox_t mailbox, bool err_irq, bool r_thr_irq, bool w_thr_irq)
{
    uint64_t ctrl_val = 0;
    ctrl_val |= w_thr_irq << MAILBOX_IRQ_WTIRQ_OFFSET;
    ctrl_val |= r_thr_irq << MAILBOX_IRQ_RTIRQ_OFFSET;
    ctrl_val |= err_irq << MAILBOX_IRQ_EIRQ_OFFSET;
    DEV_WRITE64(mailbox + MAILBOX_IRQS, ctrl_val);
}

uint8_t mailbox_get_pending_irq(mailbox_t mailbox)
{
    return (uint8_t)DEV_READ64(mailbox + MAILBOX_IRQP);
}

void mailbox_r_flush(mailbox_t mailbox)
{
    DEV_WRITE64(mailbox + MAILBOX_CTRL, MAILBOX_CTRL_FLUSH_R_MASK);
}

void mailbox_w_flush(mailbox_t mailbox)
{
    DEV_WRITE64(mailbox + MAILBOX_CTRL, MAILBOX_CTRL_FLUSH_W_MASK);
}
