// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define MAILBOX_MBOXW  (0x00) // Mailbox Write Data
#define MAILBOX_MBOXR  (0x08) // Mailbox Read Data
#define MAILBOX_STATUS (0x10) // Status Flags
#define MAILBOX_ERROR  (0x18) // Error Flags (Clear on Read)
#define MAILBOX_WIRQT  (0x20) // Write IRQ Threshold
#define MAILBOX_RIRQT  (0x28) // Read IRQ Threshold
#define MAILBOX_IRQS   (0x30) // Interrupt Status (Write 1 to Clear)
#define MAILBOX_IRQEN  (0x38) // Interrupt Enable
#define MAILBOX_IRQP   (0x40) // Interrupt Pending (ReadOnly)
#define MAILBOX_CTRL   (0x48) // Control (Flush FIFOs)

#define MAILBOX_STATUS_EMPTY_OFFSET  (0)
#define MAILBOX_STATUS_EMPTY_MASK    (0x1 << 0)
#define MAILBOX_STATUS_FULL_OFFSET   (1)
#define MAILBOX_STATUS_FULL_MASK     (0x1 << 1)
#define MAILBOX_STATUS_WFIFOL_OFFSET (2)
#define MAILBOX_STATUS_WFIFOL_MASK   (0x1 << 2)
#define MAILBOX_STATUS_RFIFOL_OFFSET (3)
#define MAILBOX_STATUS_RFIFOL_MASK   (0x1 << 3)

#define MAILBOX_ERROR_R_ERR_OFFSET (0)
#define MAILBOX_ERROR_R_ERR_MASK   (0x1 << 0)
#define MAILBOX_ERROR_W_ERR_OFFSET (1)
#define MAILBOX_ERROR_W_ERR_MASK   (0x1 << 1)

#define MAILBOX_IRQ_WTIRQ_OFFSET (0)
#define MAILBOX_IRQ_WTIRQ_MASK   (0x1 << 0)
#define MAILBOX_IRQ_RTIRQ_OFFSET (1)
#define MAILBOX_IRQ_RTIRQ_MASK   (0x1 << 1)
#define MAILBOX_IRQ_EIRQ_OFFSET  (2)
#define MAILBOX_IRQ_EIRQ_MASK    (0x1 << 2)

#define MAILBOX_CTRL_FLUSH_W_OFFSET (0)
#define MAILBOX_CTRL_FLUSH_W_MASK   (0x1 << 0)
#define MAILBOX_CTRL_FLUSH_R_OFFSET (1)
#define MAILBOX_CTRL_FLUSH_R_MASK   (0x1 << 1)

#define MAILBOX_FIFO_DEPTH (3)

typedef void *mailbox_t;

void mailbox_write(mailbox_t mailbox, uint64_t value);
uint64_t mailbox_read(mailbox_t mailbox);
bool mailbox_empty(mailbox_t mailbox);
bool mailbox_full(mailbox_t mailbox);
bool mailbox_get_r_error(mailbox_t mailbox);
bool mailbox_get_w_error(mailbox_t mailbox);
void mailbox_set_thresholds(mailbox_t mailbox, uint8_t write_threshold, uint8_t read_threshold);
void mailbox_set_irq(mailbox_t mailbox, bool err_irq, bool r_thr_irq, bool w_thr_irq);
void mailbox_ack_irq(mailbox_t mailbox, bool err_irq, bool r_thr_irq, bool w_thr_irq);
uint8_t mailbox_get_pending_irq(mailbox_t mailbox);
void mailbox_r_flush(mailbox_t mailbox);
void mailbox_w_flush(mailbox_t mailbox);
