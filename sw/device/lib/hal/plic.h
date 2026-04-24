// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/plic.h"
#include "mocha_irq.h"
#include <stdbool.h>
#include <stdint.h>

/* initialistation */
void plic_init(plic_t plic);

/* get the priority of the single interrupt 'intr' */
uint8_t plic_interrupt_priority_read(plic_t plic, enum mocha_system_irq intr);

/* set the priority of each interrupt in the set 'intr_set' to 'priority' */
void plic_interrupt_priority_write(plic_t plic, enum mocha_system_irq intr_set, uint8_t priority);

/* get the set of enabled external interrupts for M-mode */
enum mocha_system_irq plic_machine_interrupt_enable_read(plic_t plic);

/* get the set of enabled external interrupts for S-mode */
enum mocha_system_irq plic_supervisor_interrupt_enable_read(plic_t plic);

/* set the interrupts enabled for M-mode to the interrupts in 'intr_set' */
void plic_machine_interrupt_enable_write(plic_t plic, enum mocha_system_irq intr_set);

/* set the interrupts enabled for S-mode to the interrupts in 'intr_set' */
void plic_supervisor_interrupt_enable_write(plic_t plic, enum mocha_system_irq intr_set);

/* add the interrupts in 'intr_set' to the set of interrupts enabled for M-mode */
void plic_machine_interrupt_enable_set(plic_t plic, enum mocha_system_irq intr_set);

/* add the interrupts in 'intr_set' to the set of interrupts enabled for S-mode */
void plic_supervisor_interrupt_enable_set(plic_t plic, enum mocha_system_irq intr_set);

/* remove the interrupts in 'intr_set' from the set of interrupts enabled for M-mode */
void plic_machine_interrupt_enable_clear(plic_t plic, enum mocha_system_irq intr_set);

/* remove the interrupts in 'intr_set' from the set of interrupts enabled for S-mode */
void plic_supervisor_interrupt_enable_clear(plic_t plic, enum mocha_system_irq intr_set);

/* returns whether all of the interrupts in 'intr_set' are pending */
bool plic_interrupt_all_pending(plic_t plic, enum mocha_system_irq intr_set);

/* returns whether any of the interrupts in 'intr_set' are pending */
bool plic_interrupt_any_pending(plic_t plic, enum mocha_system_irq intr_set);

/* get the interrupt priority threshold for M-mode */
uint8_t plic_machine_priority_threshold_read(plic_t plic);

/* get the interrupt priority threshold for S-mode */
uint8_t plic_supervisor_priority_threshold_read(plic_t plic);

/* set the interrupt priority threshold for M-mode to 'priority' */
void plic_machine_priority_threshold_write(plic_t plic, uint8_t priority);

/* set the interrupt priority threshold for S-mode to 'priority' */
void plic_supervisor_priority_threshold_write(plic_t plic, uint8_t priority);

/* claim a single interrupt for M-mode */
enum mocha_system_irq plic_machine_interrupt_claim(plic_t plic);

/* claim a single interrupt for S-mode */
enum mocha_system_irq plic_supervisor_interrupt_claim(plic_t plic);

/* complete a single interrupt for M-mode */
void plic_machine_interrupt_complete(plic_t plic, enum mocha_system_irq intr);

/* complete a single interrupt for S-mode */
void plic_supervisor_interrupt_complete(plic_t plic, enum mocha_system_irq intr);
