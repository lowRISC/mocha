// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include <stdbool.h>
#include <stdint.h>

enum : uint64_t {
    accuracy_test_duration_us = 100ul,
    irq_test_duration_us = 50ul,
    tolerance_us = 10ul,

    min_cycle_diff = cycles_per_us * (accuracy_test_duration_us - tolerance_us),
    max_cycle_diff = cycles_per_us * (accuracy_test_duration_us + tolerance_us),
};

bool accuracy_test(timer_t timer)
{
    uint64_t start_cycle;
    uint64_t min_cycle;
    uint64_t max_cycle;
    bool has_intr_before_expire;
    bool has_intr_after_expire;

    timer_init(timer);
    timer_schedule_in_us(timer, accuracy_test_duration_us);
    timer_interrupt_enable_write(timer, true);

    start_cycle = hart_cycle_get();

    timer_enable_write(timer, true);

    min_cycle = min_cycle_diff + start_cycle;
    max_cycle = max_cycle_diff + start_cycle;

    while (hart_cycle_get() <= min_cycle) {
    }

    has_intr_before_expire = timer_interrupt_pending(timer);

    while (hart_cycle_get() <= max_cycle) {
    }

    has_intr_after_expire = timer_interrupt_pending(timer);

    return (!has_intr_before_expire && has_intr_after_expire);
}

bool timer_irq_test(timer_t timer)
{
    bool has_mtip_before_expire;
    bool has_mtip_after_expire;

    timer_init(timer);
    timer_schedule_in_us(timer, irq_test_duration_us);
    timer_interrupt_enable_write(timer, true);
    timer_enable_write(timer, true);

    has_mtip_before_expire = hart_interrupt_any_pending(interrupt_machine_timer);

    while (!timer_interrupt_pending(timer)) {
    }

    has_mtip_after_expire = hart_interrupt_any_pending(interrupt_machine_timer);

    return (!has_mtip_before_expire && has_mtip_after_expire);
}

bool test_main()
{
    timer_t timer = mocha_system_timer();

    return accuracy_test(timer) && timer_irq_test(timer);
}
