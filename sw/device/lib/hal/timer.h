// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once
#include "mocha_regs.h"
#include <stdbool.h>
#include <stdint.h>

#define TIMER_ALERT_TEST_REG (0x0)

#define TIMER_CTRL_REG (0x4)

#define TIMER_INTR_ENABLE0_REG (0x100)
#define TIMER_INTR_STATE0_REG  (0x104)
#define TIMER_INTR_TEST0_REG   (0x108)

#define TIMER_CFG0_REG      (0x10c)
#define TIMER_PRESCALE      (0)
#define TIMER_PRESCALE_MASK (0xFFF)
#define TIMER_STEP          (16)

#define TIMER_V_LOWER0_REG         (0x110)
#define TIMER_V_UPPER0_REG         (0x114)
#define TIMER_COMPARE_LOWER0_0_REG (0x118)
#define TIMER_COMPARE_UPPER0_0_REG (0x11c)

typedef void *timer_t;

void timer_disable(timer_t timer);
void timer_enable(timer_t timer);
bool timer_get_enable(timer_t timer);
void timer_set_prescale_step(timer_t timer, uint16_t prescale, uint8_t step);
uint16_t timer_get_prescale(timer_t timer);
uint8_t timer_get_step(timer_t timer);
void timer_set_compare_lower(timer_t timer, uint32_t compare_lower);
void timer_set_compare_upper(timer_t timer, uint32_t compare_upper);
void timer_set_compare(timer_t timer, uint64_t compare);
uint32_t timer_get_compare_lower(timer_t timer);
uint32_t timer_get_compare_upper(timer_t timer);
uint64_t timer_get_compare(timer_t timer);
void timer_set_value_lower(timer_t timer, uint32_t value_lower);
void timer_set_value_upper(timer_t timer, uint32_t value_upper);
void timer_set_value(timer_t timer, uint64_t value);
uint32_t timer_get_value_lower(timer_t timer);
uint32_t timer_get_value_upper(timer_t timer);
uint64_t timer_get_value(timer_t timer);
void timer_disable_interrupt(timer_t timer);
void timer_enable_interrupt(timer_t timer);
bool timer_get_interrupt_enable(timer_t timer);
bool timer_has_interrupt(timer_t timer);
void timer_clear_interrupt(timer_t timer);
void timer_trigger_alert(timer_t timer);
void timer_trigger_interrupt(timer_t timer);

void timer_init(timer_t timer);
void timer_busy_sleep(timer_t timer, uint64_t duration_steps);
