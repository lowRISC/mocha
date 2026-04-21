// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// RISC-V Hart functions.

#pragma once

#include "builtin.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

enum [[clang::flag_enum]] interrupt : unsigned long {
    interrupt_supervisor_software = (1u << 1),
    interrupt_machine_software = (1u << 3),
    interrupt_software_timer = (1u << 5),
    interrupt_machine_timer = (1u << 7),
    interrupt_software_external = (1u << 9),
    interrupt_machine_external = (1u << 11),
};

struct [[gnu::aligned(8)]] mstatus {
    unsigned long : 3;
    bool mie : 1;
    unsigned long : 60;
};

_Static_assert(sizeof(struct mstatus) == sizeof(unsigned long), "incorrect struct mstatus size");

/* interrupts */
static inline bool hart_global_interrupt_enable_set(bool enable);
static inline enum interrupt hart_interrupt_enable_get(void);
static inline void hart_interrupt_enable_write(enum interrupt interrupts);
static inline void hart_interrupt_enable_set(enum interrupt interrupts);
static inline void hart_interrupt_enable_clear(enum interrupt interrupts);
static inline void hart_interrupt_clear(enum interrupt interrupts);
static inline bool hart_interrupt_any_pending(enum interrupt interrupts);

/* cycle counter */
static inline uint64_t hart_cycle_get(void);
/* hartid */
static inline unsigned long hart_hartid_get(void);

static inline bool hart_global_interrupt_enable_set(bool enable)
{
    struct mstatus mstatus;
    asm volatile("csrr %0, mstatus" : "=r"(mstatus)::);
    bool ret = mstatus.mie;
    mstatus.mie = enable;
    asm volatile("csrw mstatus, %0" ::"r"(mstatus) :);
    return ret;
}

static inline enum interrupt hart_interrupt_enable_get(void)
{
    enum interrupt mie;
    asm volatile("csrr %0, mie" : "=r"(mie)::);
    return mie;
}

static inline void hart_interrupt_enable_write(enum interrupt interrupts)
{
    asm volatile("csrw mie, %0" ::"r"(interrupts) :);
}

static inline void hart_interrupt_enable_set(enum interrupt interrupts)
{
    asm volatile("csrs mie, %0" ::"r"(interrupts) :);
}

static inline void hart_interrupt_enable_clear(enum interrupt interrupts)
{
    asm volatile("csrc mie, %0" ::"r"(interrupts) :);
}

static inline void hart_interrupt_clear(enum interrupt interrupts)
{
    asm volatile("csrc mip, %0" ::"r"(interrupts) :);
}

static inline bool hart_interrupt_any_pending(enum interrupt interrupts)
{
    enum interrupt mip;
    asm volatile("csrr %0, mip" : "=r"(mip)::);
    return (mip & interrupts) != 0u;
}

static inline uint64_t hart_cycle_get(void)
{
    uint64_t cycle;
    asm volatile("csrr %0, cycle" : "=r"(cycle)::);
    return cycle;
}

static inline unsigned long hart_hartid_get(void)
{
    unsigned long hartid;
    asm volatile("csrr %0, mhartid" : "=r"(hartid)::);
    return hartid;
}

/* wait for a condition to be true, allowing preemption by interrupts */
#define WAIT_FOR_CONDITION_PREEMPTABLE(volatile_condition) \
    do { \
        /* save the global interrupt enable state */ \
        bool saved_enable = hart_global_interrupt_enable_set(false); \
        while (!(volatile_condition)) { \
            asm volatile("wfi"); \
            /* toggle global interrupt enable so that we maybe get preempted */ \
            hart_global_interrupt_enable_set(true); \
            /* disable again before we check the condition */ \
            hart_global_interrupt_enable_set(false); \
        } \
        /* restore */ \
        (void)hart_global_interrupt_enable_set(saved_enable); \
    } while (0)
