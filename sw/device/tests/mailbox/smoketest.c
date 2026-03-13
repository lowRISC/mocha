// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mailbox.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

// Check that we can write and access some mailbox registers
static bool reg_test(mailbox_t mailbox)
{
    bool result = true;

    // clear mailbox
    mailbox_r_flush(mailbox);
    mailbox_w_flush(mailbox);

    // ack already pending interrupts
    mailbox_ack_irq(mailbox, true, true, true);

    // set threshold registers
    mailbox_set_thresholds(mailbox, MAILBOX_FIFO_DEPTH, MAILBOX_FIFO_DEPTH);

    // enable interrupts
    mailbox_set_irq(mailbox, true, true, true);

    // read FIFO should be empty
    result &= mailbox_empty(mailbox);

    // write FIFO should be empty
    result &= !mailbox_full(mailbox);

    // write N elements to FIFO fill it up
    for (int i = 0; i < MAILBOX_FIFO_DEPTH; i++) {
        mailbox_write(mailbox, 0xbeef0000 + i);
    }

    // write FIFO should be full
    result &= mailbox_full(mailbox);

    // check interrupts
    result &= (mailbox_get_pending_irq(mailbox) == 0x1);

    // clear mailbox
    mailbox_r_flush(mailbox);
    mailbox_w_flush(mailbox);

    // ack pending w_full interrupt
    mailbox_ack_irq(mailbox, false, false, true);

    // write FIFO should be empty
    result &= !mailbox_full(mailbox);

    // no interrupt pending
    result &= (mailbox_get_pending_irq(mailbox) == 0x0);

    return result;
}

bool test_main()
{
    mailbox_t mailbox = mocha_system_mailbox();
    return reg_test(mailbox);
}
