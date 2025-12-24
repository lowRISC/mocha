// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha_regs.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

bool accuracy_test(timer_t timer)
{
    uint64_t start_cycle;
    uint64_t current_cycle;
    uint64_t min_cycle;
    uint64_t max_cycle;
    bool has_intr_before_expire;
    bool has_intr_after_expire;

    const uint64_t duration_steps = 100;
    const uint64_t tolerance_steps = 10;

    const uint64_t min_cycle_diff = (duration_steps - tolerance_steps) * (SYSCLK_FREQ / 1000000);
    const uint64_t max_cycle_diff = (duration_steps + tolerance_steps) * (SYSCLK_FREQ / 1000000);

    timer_init(timer);
    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); // 1 tick/us
    timer_set_compare(timer, timer_get_value(timer) + duration_steps);
    timer_clear_interrupt(timer);

    __asm__ volatile("csrr %0, cycle\n\t" : "=r"(start_cycle));

    timer_enable(timer);

    min_cycle = min_cycle_diff + start_cycle;
    max_cycle = max_cycle_diff + start_cycle;

    while (1) {
        __asm__ volatile("csrr %0, cycle\n\t" : "=r"(current_cycle));
        if (current_cycle > min_cycle) {
            break;
        }
    }

    has_intr_before_expire = timer_has_interrupt(timer);

    while (1) {
        __asm__ volatile("csrr %0, cycle\n\t" : "=r"(current_cycle));
        if (current_cycle > max_cycle) {
            break;
        }
    }

    has_intr_after_expire = timer_has_interrupt(timer);

    return (!has_intr_before_expire && has_intr_after_expire);
}

bool timer_irq_test(timer_t timer)
{
    uint64_t mip;
    bool has_mtip_before_expire;
    bool has_mtip_after_expire;

    const uint64_t MTIP_MASK = (1 << 7);
    const uint64_t duration_steps = 5;

    timer_init(timer);
    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); // 1 tick/us
    timer_set_compare(timer, timer_get_value(timer) + duration_steps);
    timer_clear_interrupt(timer);
    timer_enable_interrupt(timer);

    timer_enable(timer);

    __asm__ volatile("csrr %0, mip\n\t" : "=r"(mip));
    has_mtip_before_expire = ((mip & MTIP_MASK) != 0);

    while (!timer_has_interrupt(timer)) {
    }

    __asm__ volatile("csrr %0, mip\n\t" : "=r"(mip));
    has_mtip_after_expire = ((mip & MTIP_MASK) != 0);

    return (!has_mtip_before_expire && has_mtip_after_expire);
}

bool test_main()
{
    timer_t timer = (timer_t)TIMER_BASE;

    return accuracy_test(timer) && timer_irq_test(timer);
}
