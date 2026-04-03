// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/plic.h"
#include <stdbool.h>
#include <stdint.h>

/* initialistation */
void plic_init(plic_t plic);

uint8_t plic_interrupt_priority_read(plic_t plic, uint32_t intr);
void plic_interrupt_priority_write(plic_t plic, uint32_t intrs, uint8_t prio);
uint32_t plic_machine_interrupt_enable_read(plic_t plic);
uint32_t plic_supervisor_interrupt_enable_read(plic_t plic);
void plic_machine_interrupt_enable_write(plic_t plic, uint32_t intrs);
void plic_supervisor_interrupt_enable_write(plic_t plic, uint32_t intrs);
void plic_machine_interrupt_enable_set(plic_t plic, uint32_t intrs);
void plic_supervisor_interrupt_enable_set(plic_t plic, uint32_t intrs);
void plic_machine_interrupt_enable_clear(plic_t plic, uint32_t intrs);
void plic_supervisor_interrupt_enable_clear(plic_t plic, uint32_t intrs);
bool plic_interrupt_all_pending(plic_t plic, uint32_t intrs);
bool plic_interrupt_any_pending(plic_t plic, uint32_t intrs);
uint8_t plic_machine_priority_threshold_read(plic_t plic);
uint8_t plic_supervisor_priority_threshold_read(plic_t plic);
void plic_machine_priority_threshold_write(plic_t plic, uint8_t prio);
void plic_supervisor_priority_threshold_write(plic_t plic, uint8_t prio);
uint32_t plic_machine_interrupt_claim(plic_t plic);
uint32_t plic_supervisor_interrupt_claim(plic_t plic);
void plic_machine_interrupt_complete(plic_t plic, uint32_t intr);
void plic_supervisor_interrupt_complete(plic_t plic, uint32_t intr);
