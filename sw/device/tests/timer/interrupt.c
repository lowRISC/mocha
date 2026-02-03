// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

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
    unsigned long mstatus;
    __asm__ volatile("csrr %0, mstatus" : "=r"(mstatus)::);
    mstatus &= ~(1 << 3);
    __asm__ volatile("csrw mstatus, %0" ::"r"(mstatus) :);

    /* enable all interrupts at the hart */
    unsigned long mie = ~(0);
    __asm__ volatile("csrw mie, %0" ::"r"(mie) :);

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

        do {
            /* disable interrupts globally */
            __asm__ volatile("csrr %0, mstatus" : "=r"(mstatus)::);
            mstatus &= ~(1 << 3);
            __asm__ volatile("csrw mstatus, %0" ::"r"(mstatus) :);

            /* check the condition, and break if set */
            if (interrupt_handled) {
                break;
            }
            /* wfi to pause the hart until an interrupt is pending */
            __asm__ volatile("wfi");
            /* enable interrupts globally to possibly be pre-empted */
            mstatus |= (1 << 3);
            __asm__ volatile("csrw mstatus, %0" ::"r"(mstatus) :);
        } while (true);
    }

    return true;
}

bool test_interrupt_handler(size_t irq)
{
    if (irq == 7) {
        /* machine mode timer interrupt */
        /* set next timer interrupt to be infinitely far into the future */
        timer_set_compare(timer, ~(0));
        /* clear the timer interrupt */
        timer_clear_interrupt(timer);
        interrupt_handled = true;
        return true;
    }
    /* all other interrupts are unexpected */
    return false;
}
