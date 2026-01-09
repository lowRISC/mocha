// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define PLIC_PRIO_REG  (0x0)
#define PLIC_PRIO_MASK (0x3)

#define PLIC_IP_REG         (0x1000)
#define PLIC_IE0_REG        (0x2000)
#define PLIC_IE1_REG        (0x2100)
#define PLIC_THRESHOLD0_REG (0x200000)
#define PLIC_THRESHOLD1_REG (0x201000)
#define PLIC_CC0_REG        (0x200004)
#define PLIC_CC1_REG        (0x201004)
#define PLIC_MSIP0_REG      (0x4000000)
#define PLIC_MSIP1_REG      (0x4000004)
#define PLIC_ALERT_TEST_REG (0x4004000)

#define PLIC_NUM_SRC (32)

typedef void *plic_t;

uint8_t plic_interrupt_priority_get(plic_t plic, uint8_t intr_id);
void plic_interrupt_priority_set(plic_t plic, uint8_t intr_id, uint8_t prio);
bool plic_interrupt_is_pending(plic_t plic, uint8_t intr_id);
bool plic_machine_interrupt_enable_get(plic_t plic, uint8_t intr_id);
bool plic_supervisor_interrupt_enable_get(plic_t plic, uint8_t intr_id);
void plic_machine_interrupt_enable(plic_t plic, uint8_t intr_id);
void plic_supervisor_interrupt_enable(plic_t plic, uint8_t intr_id);
void plic_machine_interrupt_disable(plic_t plic, uint8_t intr_id);
void plic_supervisor_interrupt_disable(plic_t plic, uint8_t intr_id);
void plic_machine_interrupt_disable_all(plic_t plic);
void plic_supervisor_interrupt_disable_all(plic_t plic);
uint8_t plic_machine_priority_threshold_get(plic_t plic);
uint8_t plic_supervisor_priority_threshold_get(plic_t plic);
void plic_machine_priority_threshold_set(plic_t plic, uint8_t prio);
void plic_supervisor_priority_threshold_set(plic_t plic, uint8_t prio);
uint8_t plic_machine_interrupt_claim(plic_t plic);
uint8_t plic_supervisor_interrupt_claim(plic_t plic);
void plic_machine_interrupt_complete(plic_t plic, uint8_t intr_id);
void plic_supervisor_interrupt_complete(plic_t plic, uint8_t intr_id);
void plic_alert_trigger(plic_t plic);

void plic_init(plic_t plic);
