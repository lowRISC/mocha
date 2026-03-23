// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include <stdbool.h>

timer_t timer = NULL;
volatile bool interrupt_handled = false;

bool test_main(uart_t console)
{
    (void)console;

    /* globally disable all interrupts at the hart */
    hart_global_interrupt_enable_set(false);

    /* enable all interrupts at the hart */
    hart_interrupt_enable(interrupt_machine_timer);

    /* initialise the timer */
    timer = mocha_system_timer();
    timer_init(timer);
    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); /* 1 tick/us */
    timer_enable_interrupt(timer);
    timer_enable(timer);

    for (size_t i = 0; i < 10; i++) {
        /* schedule an interrupt 100us from now */
        interrupt_handled = false;
        timer_set_compare(timer, timer_get_value(timer) + 100);
        WAIT_FOR_CONDITION_PREEMPTABLE(interrupt_handled);
    }

    return true;
}

bool test_interrupt_handler(enum interrupt interrupt)
{
    if (interrupt == interrupt_machine_timer) {
        /* machine mode timer interrupt */
        /* set next timer interrupt to be infinitely far into the future */
        timer_set_compare(timer, UINT64_MAX);
        /* clear the timer interrupt */
        timer_clear_interrupt(timer);
        interrupt_handled = true;
        return true;
    }
    /* all other interrupts are unexpected */
    return false;
}
