// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/plic.h"
#include "builtin.h"
#include "hal/mmio.h"
#include "hal/mocha_irq.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

void plic_init(plic_t plic)
{
    plic_machine_interrupt_enable_write(plic, 0u);
    plic_supervisor_interrupt_enable_write(plic, 0u);
}

uint8_t plic_interrupt_priority_read(plic_t plic, enum mocha_system_irq intr)
{
    if (intr == 0u) {
        return 0u;
    }
    /* TODO: panic if more than one irq bit is set */
    size_t id = ctz(intr);
    plic_prio prio = VOLATILE_READ(plic->prio[id]);
    return prio.prio;
}

void plic_interrupt_priority_write(plic_t plic, enum mocha_system_irq intr_set, uint8_t priority)
{
    if (intr_set == 0u) {
        return;
    }

    enum mocha_system_irq remain = intr_set;
    do {
        size_t id = ctz(remain);
        remain &= ~(1u << id);
        plic_prio prio = { .prio = priority };
        VOLATILE_WRITE(plic->prio[id], prio);
    } while (remain != 0u);
}

enum mocha_system_irq plic_machine_interrupt_enable_read(plic_t plic)
{
    return (enum mocha_system_irq)VOLATILE_READ(plic->ie0);
}

enum mocha_system_irq plic_supervisor_interrupt_enable_read(plic_t plic)
{
    return (enum mocha_system_irq)VOLATILE_READ(plic->ie1);
}

void plic_machine_interrupt_enable_write(plic_t plic, enum mocha_system_irq intr_set)
{
    VOLATILE_WRITE(plic->ie0, intr_set);
}

void plic_supervisor_interrupt_enable_write(plic_t plic, enum mocha_system_irq intr_set)
{
    VOLATILE_WRITE(plic->ie1, intr_set);
}

void plic_machine_interrupt_enable_set(plic_t plic, enum mocha_system_irq intr_set)
{
    uint32_t ie0 = VOLATILE_READ(plic->ie0);
    ie0 |= intr_set;
    VOLATILE_WRITE(plic->ie0, ie0);
}

void plic_supervisor_interrupt_enable_set(plic_t plic, enum mocha_system_irq intr_set)
{
    uint32_t ie1 = VOLATILE_READ(plic->ie1);
    ie1 |= intr_set;
    VOLATILE_WRITE(plic->ie1, ie1);
}

void plic_machine_interrupt_enable_clear(plic_t plic, enum mocha_system_irq intr_set)
{
    uint32_t ie0 = VOLATILE_READ(plic->ie0);
    ie0 &= ~intr_set;
    VOLATILE_WRITE(plic->ie0, ie0);
}

void plic_supervisor_interrupt_enable_clear(plic_t plic, enum mocha_system_irq intr_set)
{
    uint32_t ie1 = VOLATILE_READ(plic->ie1);
    ie1 &= ~intr_set;
    VOLATILE_WRITE(plic->ie1, ie1);
}

bool plic_interrupt_all_pending(plic_t plic, enum mocha_system_irq intr_set)
{
    return (VOLATILE_READ(plic->ip) & intr_set) == intr_set;
}

bool plic_interrupt_any_pending(plic_t plic, enum mocha_system_irq intr_set)
{
    return (VOLATILE_READ(plic->ip) & intr_set) != 0u;
}

uint8_t plic_machine_priority_threshold_read(plic_t plic)
{
    plic_threshold0 threshold = VOLATILE_READ(plic->threshold0);
    return threshold.threshold0;
}

uint8_t plic_supervisor_priority_threshold_read(plic_t plic)
{
    plic_threshold1 threshold = VOLATILE_READ(plic->threshold1);
    return threshold.threshold1;
}

void plic_machine_priority_threshold_write(plic_t plic, uint8_t priority)
{
    plic_threshold0 threshold = { .threshold0 = priority };
    VOLATILE_WRITE(plic->threshold0, threshold);
}

void plic_supervisor_priority_threshold_write(plic_t plic, uint8_t priority)
{
    plic_threshold1 threshold = { .threshold1 = priority };
    VOLATILE_WRITE(plic->threshold1, threshold);
}

enum mocha_system_irq plic_machine_interrupt_claim(plic_t plic)
{
    plic_cc0 claim = VOLATILE_READ(plic->cc0);
    return (enum mocha_system_irq)(1u << claim.cc0);
}

enum mocha_system_irq plic_supervisor_interrupt_claim(plic_t plic)
{
    plic_cc1 claim = VOLATILE_READ(plic->cc1);
    return (enum mocha_system_irq)(1u << claim.cc1);
}

void plic_machine_interrupt_complete(plic_t plic, enum mocha_system_irq intr)
{
    if (intr == 0u) {
        return;
    }
    /* TODO: panic if more than one irq bit is set */
    size_t id = ctz(intr);
    plic_cc0 complete = { .cc0 = id };
    VOLATILE_WRITE(plic->cc0, complete);
}

void plic_supervisor_interrupt_complete(plic_t plic, enum mocha_system_irq intr)
{
    if (intr == 0u) {
        return;
    }
    /* TODO: panic if more than one irq bit is set */
    size_t id = ctz(intr);
    plic_cc1 complete = { .cc1 = id };
    VOLATILE_WRITE(plic->cc1, complete);
}
