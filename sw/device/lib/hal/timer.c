// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "timer.h"
#include "mocha_regs.h"
#include <stdbool.h>
#include <stdint.h>

void timer_disable(timer_t timer)
{
    DEV_WRITE(timer + TIMER_CTRL_REG, 0x0);
}

void timer_enable(timer_t timer)
{
    DEV_WRITE(timer + TIMER_CTRL_REG, 0x1);
}

bool timer_get_enable(timer_t timer)
{
    return ((DEV_READ(timer + TIMER_CTRL_REG) & 0x1) == 0x1);
}

void timer_set_prescale_step(timer_t timer, uint16_t prescale, uint8_t step)
{
    DEV_WRITE(timer + TIMER_CFG0_REG,
              (step << TIMER_STEP) | ((prescale & TIMER_PRESCALE_MASK) << TIMER_PRESCALE));
}

uint16_t timer_get_prescale(timer_t timer)
{
    return (uint16_t)(DEV_READ(timer + TIMER_CFG0_REG) & TIMER_PRESCALE_MASK);
}

uint8_t timer_get_step(timer_t timer)
{
    return (uint8_t)(DEV_READ(timer + TIMER_CFG0_REG) >> TIMER_STEP);
}

void timer_set_compare_lower(timer_t timer, uint32_t compare_lower)
{
    DEV_WRITE(timer + TIMER_COMPARE_LOWER0_0_REG, compare_lower);
}

void timer_set_compare_upper(timer_t timer, uint32_t compare_upper)
{
    DEV_WRITE(timer + TIMER_COMPARE_UPPER0_0_REG, compare_upper);
}

void timer_set_compare(timer_t timer, uint64_t compare)
{
    timer_set_compare_lower(timer, (uint32_t)(compare & 0xFFFFFFFF));
    timer_set_compare_upper(timer, (uint32_t)(compare >> 32));
}

uint32_t timer_get_compare_lower(timer_t timer)
{
    return DEV_READ(timer + TIMER_COMPARE_LOWER0_0_REG);
}

uint32_t timer_get_compare_upper(timer_t timer)
{
    return DEV_READ(timer + TIMER_COMPARE_UPPER0_0_REG);
}

uint64_t timer_get_compare(timer_t timer)
{
    return (((uint64_t)timer_get_compare_upper(timer)) << 32) |
           ((uint64_t)timer_get_compare_lower(timer));
}

void timer_set_value_lower(timer_t timer, uint32_t value_lower)
{
    DEV_WRITE(timer + TIMER_V_LOWER0_REG, value_lower);
}

void timer_set_value_upper(timer_t timer, uint32_t value_upper)
{
    DEV_WRITE(timer + TIMER_V_UPPER0_REG, value_upper);
}

void timer_set_value(timer_t timer, uint64_t value)
{
    timer_set_value_lower(timer, (uint32_t)(value & 0xFFFFFFFF));
    timer_set_value_upper(timer, (uint32_t)(value >> 32));
}

uint32_t timer_get_value_lower(timer_t timer)
{
    return DEV_READ(timer + TIMER_V_LOWER0_REG);
}

uint32_t timer_get_value_upper(timer_t timer)
{
    return DEV_READ(timer + TIMER_V_UPPER0_REG);
}

uint64_t timer_get_value(timer_t timer)
{
    return (((uint64_t)timer_get_value_upper(timer)) << 32) |
           ((uint64_t)timer_get_value_lower(timer));
}

void timer_disable_interrupt(timer_t timer)
{
    DEV_WRITE(timer + TIMER_INTR_ENABLE0_REG, 0x0);
}

void timer_enable_interrupt(timer_t timer)
{
    DEV_WRITE(timer + TIMER_INTR_ENABLE0_REG, 0x1);
}

bool timer_get_interrupt_enable(timer_t timer)
{
    return ((DEV_READ(timer + TIMER_INTR_ENABLE0_REG) & 0x1) == 0x1);
}

bool timer_has_interrupt(timer_t timer)
{
    return ((DEV_READ(timer + TIMER_INTR_STATE0_REG) & 0x1) == 0x1);
}

void timer_clear_interrupt(timer_t timer)
{
    DEV_WRITE(timer + TIMER_INTR_STATE0_REG, 0x1);
}

void timer_trigger_alert(timer_t timer)
{
    DEV_WRITE(timer + TIMER_ALERT_TEST_REG, 0x1);
}

void timer_trigger_interrupt(timer_t timer)
{
    DEV_WRITE(timer + TIMER_INTR_TEST0_REG, 0x1);
}

void timer_init(timer_t timer)
{
    timer_disable(timer);
    timer_disable_interrupt(timer);
}

void timer_busy_sleep(timer_t timer, uint64_t duration_steps)
{
    timer_set_compare(timer, timer_get_value(timer) + duration_steps);
    timer_clear_interrupt(timer);

    // Poll for interrupt
    while (!timer_has_interrupt(timer)) {
    }
}
