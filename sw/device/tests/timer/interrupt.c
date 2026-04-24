// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include <stdbool.h>

volatile timer_t timer = NULL;
volatile bool interrupt_handled = false;

bool test_main(uart_t console)
{
    (void)console;

    /* initialise the timer */
    timer = mocha_system_timer();
    timer_init(timer);

    /* globally disable all interrupts at the hart */
    hart_global_interrupt_enable_set(false);

    /* enable timer interrupt at the hart */
    hart_interrupt_enable_write(interrupt_machine_timer);

    /* enable timer interrupt */
    timer_interrupt_enable_write(timer, true);

    timer_enable_write(timer, true);

    for (size_t i = 0; i < 10; i++) {
        /* schedule an interrupt 100us from now */
        interrupt_handled = false;
        timer_schedule_in_us(timer, 100u);
        WAIT_FOR_CONDITION_PREEMPTABLE(interrupt_handled);
    }

    return true;
}

bool test_interrupt_handler(enum interrupt interrupt)
{
    if (interrupt == interrupt_machine_timer) {
        /* machine mode timer interrupt, clear the interrupt by scheduling
         * an interrupt infinitely far into the future */
        timer_interrupt_clear(timer);
        interrupt_handled = true;
        return true;
    }
    /* all other interrupts are unexpected */
    return false;
}
