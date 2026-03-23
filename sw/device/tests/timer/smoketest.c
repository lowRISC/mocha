// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include <stdbool.h>
#include <stdint.h>

bool accuracy_test(timer_t timer)
{
    uint64_t start_cycle;
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

    start_cycle = hart_cycle_get();

    timer_enable(timer);

    min_cycle = min_cycle_diff + start_cycle;
    max_cycle = max_cycle_diff + start_cycle;

    while (hart_cycle_get() <= min_cycle) {
    }

    has_intr_before_expire = timer_has_interrupt(timer);

    while (hart_cycle_get() <= max_cycle) {
    }

    has_intr_after_expire = timer_has_interrupt(timer);

    return (!has_intr_before_expire && has_intr_after_expire);
}

bool timer_irq_test(timer_t timer)
{
    bool has_mtip_before_expire;
    bool has_mtip_after_expire;

    const uint64_t duration_steps = 5;

    timer_init(timer);
    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); // 1 tick/us
    timer_set_compare(timer, timer_get_value(timer) + duration_steps);
    timer_clear_interrupt(timer);
    timer_enable_interrupt(timer);

    timer_enable(timer);

    has_mtip_before_expire = hart_interrupt_any_pending(interrupt_machine_timer);

    while (!timer_has_interrupt(timer)) {
    }

    has_mtip_after_expire = hart_interrupt_any_pending(interrupt_machine_timer);

    return (!has_mtip_before_expire && has_mtip_after_expire);
}

bool test_main()
{
    timer_t timer = mocha_system_timer();

    return accuracy_test(timer) && timer_irq_test(timer);
}
