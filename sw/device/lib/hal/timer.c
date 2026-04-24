// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/timer.h"
#include "builtin.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static void timer_compare_write(timer_t timer, uint64_t compare);

void timer_init(timer_t timer)
{
    timer_enable_write(timer, false);
    timer_interrupt_enable_write(timer, false);
    timer_interrupt_clear(timer);
    /* lowest prescale value gives the most accurate timing */
    timer_cfg0 cfg = {
        .prescale = 0,
        .step = 1u,
    };
    VOLATILE_WRITE(timer->cfg0, cfg);
}

bool timer_interrupt_enable_read(timer_t timer)
{
    timer_intr_enable0 intr_enable = VOLATILE_READ(timer->intr_enable0);
    return intr_enable.ie;
}

void timer_interrupt_enable_write(timer_t timer, bool enable)
{
    timer_intr_enable0 intr_enable = { .ie = enable };
    VOLATILE_WRITE(timer->intr_enable0, intr_enable);
}

void timer_interrupt_force(timer_t timer)
{
    timer_intr_test0 intr_test = { .t = true };
    VOLATILE_WRITE(timer->intr_test0, intr_test);
}

void timer_interrupt_clear(timer_t timer)
{
    /* the rv_timer is effectively a level-triggered interrupt, so to
     * clear it we can schedule an interrupt infinitely far away... */
    timer_compare_write(timer, UINT64_MAX);
    /* ...then clear the latched interrupt bit */
    timer_intr_state0 intr_state = { .is = true };
    VOLATILE_WRITE(timer->intr_state0, intr_state);
}

bool timer_interrupt_pending(timer_t timer)
{
    timer_intr_state0 intr_state = VOLATILE_READ(timer->intr_state0);
    return intr_state.is;
}

void timer_enable_write(timer_t timer, bool enable)
{
    timer_ctrl ctrl = { .active = enable };
    VOLATILE_WRITE(timer->ctrl, ctrl);
}

uint64_t timer_value_read(timer_t timer)
{
    uint32_t timer_lower, timer_upper, timer_upper_again;
    do {
        /* make sure the lower half of the timer value does
         * not overflow while reading the two halves, see
         * Unprivileged Spec Chapter 7.1 */
        timer_upper = VOLATILE_READ(timer->timer_v_upper0);
        timer_lower = VOLATILE_READ(timer->timer_v_lower0);
        timer_upper_again = VOLATILE_READ(timer->timer_v_upper0);
    } while (timer_upper != timer_upper_again);

    return (((uint64_t)timer_upper) << 32u) | timer_lower;
}

static void timer_compare_write(timer_t timer, uint64_t compare)
{
    uint32_t compare_lower = (uint32_t)compare;
    uint32_t compare_upper = (uint32_t)(compare >> 32u);

    /* write all 1s to the bottom half first, then the top and
     * bottom to not cause a spurious interrupt from writing an
     * intermediate value, see Privileged Spec Chapter 3.2.1 */
    VOLATILE_WRITE(timer->compare_lower0_0, UINT32_MAX);
    VOLATILE_WRITE(timer->compare_upper0_0, compare_upper);
    VOLATILE_WRITE(timer->compare_lower0_0, compare_lower);
}

static inline uint64_t timer_ticks_per_us(timer_t timer)
{
    timer_cfg0 cfg = VOLATILE_READ(timer->cfg0);
    /* ticks     cycles     ticks      steps
     * ------ =  ------  x  ------  x  -----
     *   us        us        step      cycle
     *
     *           cycles     ticks      cycles
     *        =  ------  x  ------  /  ------
     *             us        step       step
     *
     *        = cycles/us x cfg.step / (cfg.prescale + 1) */
    return (cycles_per_us * cfg.step) / ((uint64_t)cfg.prescale + 1u);
}

void timer_schedule_in_ticks(timer_t timer, uint64_t ticks)
{
    uint64_t next;
    if (uaddl_overflow(timer_value_read(timer), ticks, &next)) {
        next = UINT64_MAX;
    }
    timer_compare_write(timer, next);
}

void timer_schedule_in_us(timer_t timer, uint64_t us)
{
    uint64_t ticks;
    if (umull_overflow(us, timer_ticks_per_us(timer), &ticks)) {
        ticks = UINT64_MAX;
    }
    timer_schedule_in_ticks(timer, ticks);
}

void timer_busy_sleep_us(timer_t timer, uint64_t us)
{
    timer_schedule_in_us(timer, us);
    while (!timer_interrupt_pending(timer)) {
    }
}

uint64_t timer_value_read_us(timer_t timer)
{
    return timer_value_read(timer) / timer_ticks_per_us(timer);
}
