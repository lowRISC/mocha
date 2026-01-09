// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/plic.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

uint8_t plic_interrupt_priority_get(plic_t plic, uint8_t intr_id)
{
    if (intr_id >= PLIC_NUM_SRC) {
        return 0;
    }
    return (DEV_READ(plic + PLIC_PRIO_REG + 4 * intr_id) & PLIC_PRIO_MASK);
}

void plic_interrupt_priority_set(plic_t plic, uint8_t intr_id, uint8_t prio)
{
    if (intr_id < PLIC_NUM_SRC) {
        DEV_WRITE(plic + PLIC_PRIO_REG + 4 * intr_id, prio & PLIC_PRIO_MASK);
    }
}

bool plic_interrupt_is_pending(plic_t plic, uint8_t intr_id)
{
    return ((DEV_READ(plic + PLIC_IP_REG) & (1 << intr_id)) != 0);
}

bool plic_machine_interrupt_enable_get(plic_t plic, uint8_t intr_id)
{
    return ((DEV_READ(plic + PLIC_IE0_REG) & (1 << intr_id)) != 0);
}

bool plic_supervisor_interrupt_enable_get(plic_t plic, uint8_t intr_id)
{
    return ((DEV_READ(plic + PLIC_IE1_REG) & (1 << intr_id)) != 0);
}

void plic_machine_interrupt_enable(plic_t plic, uint8_t intr_id)
{
    DEV_WRITE(plic + PLIC_IE0_REG, DEV_READ(plic + PLIC_IE0_REG) | (1 << intr_id));
}

void plic_supervisor_interrupt_enable(plic_t plic, uint8_t intr_id)
{
    DEV_WRITE(plic + PLIC_IE1_REG, DEV_READ(plic + PLIC_IE1_REG) | (1 << intr_id));
}

void plic_machine_interrupt_disable(plic_t plic, uint8_t intr_id)
{
    DEV_WRITE(plic + PLIC_IE0_REG, DEV_READ(plic + PLIC_IE0_REG) & ~(1 << intr_id));
}

void plic_supervisor_interrupt_disable(plic_t plic, uint8_t intr_id)
{
    DEV_WRITE(plic + PLIC_IE1_REG, DEV_READ(plic + PLIC_IE1_REG) & ~(1 << intr_id));
}

void plic_machine_interrupt_disable_all(plic_t plic)
{
    DEV_WRITE(plic + PLIC_IE0_REG, 0);
}

void plic_supervisor_interrupt_disable_all(plic_t plic)
{
    DEV_WRITE(plic + PLIC_IE1_REG, 0);
}

uint8_t plic_machine_priority_threshold_get(plic_t plic)
{
    return (DEV_READ(plic + PLIC_THRESHOLD0_REG) & PLIC_PRIO_MASK);
}

uint8_t plic_supervisor_priority_threshold_get(plic_t plic)
{
    return (DEV_READ(plic + PLIC_THRESHOLD1_REG) & PLIC_PRIO_MASK);
}

void plic_machine_priority_threshold_set(plic_t plic, uint8_t prio)
{
    DEV_WRITE(plic + PLIC_THRESHOLD0_REG, prio & PLIC_PRIO_MASK);
}

void plic_supervisor_priority_threshold_set(plic_t plic, uint8_t prio)
{
    DEV_WRITE(plic + PLIC_THRESHOLD1_REG, prio & PLIC_PRIO_MASK);
}

uint8_t plic_machine_interrupt_claim(plic_t plic)
{
    return (uint8_t)DEV_READ(plic + PLIC_CC0_REG);
}

uint8_t plic_supervisor_interrupt_claim(plic_t plic)
{
    return (uint8_t)DEV_READ(plic + PLIC_CC1_REG);
}

void plic_machine_interrupt_complete(plic_t plic, uint8_t intr_id)
{
    DEV_WRITE(plic + PLIC_CC0_REG, (uint32_t)intr_id);
}

void plic_supervisor_interrupt_complete(plic_t plic, uint8_t intr_id)
{
    DEV_WRITE(plic + PLIC_CC1_REG, (uint32_t)intr_id);
}

void plic_alert_trigger(plic_t plic)
{
    DEV_WRITE(plic + PLIC_ALERT_TEST_REG, 1);
}

void plic_init(plic_t plic)
{
    plic_machine_interrupt_disable_all(plic);
    plic_supervisor_interrupt_disable_all(plic);
}
