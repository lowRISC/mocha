// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/clkmgr.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

static uint32_t clkmgr_read(clkmgr_t clkmgr, uintptr_t reg)
{
    return DEV_READ(clkmgr + reg);
}

static void clkmgr_write(clkmgr_t clkmgr, uintptr_t reg, uint32_t value)
{
    DEV_WRITE(clkmgr + reg, value);
}

static uint32_t clkmgr_bit(size_t clock)
{
    return 1u << clock;
}

bool clkmgr_gateable_clock_get_enabled(clkmgr_t clkmgr, size_t clock)
{
    return (clkmgr_read(clkmgr, CLKMGR_CLK_ENABLES_REG) & clkmgr_bit(clock)) != 0;
}

void clkmgr_gateable_clock_set_enabled(clkmgr_t clkmgr, size_t clock, bool enabled)
{
    uint32_t reg = clkmgr_read(clkmgr, CLKMGR_CLK_ENABLES_REG);
    if (enabled) {
        reg |= clkmgr_bit(clock);
    } else {
        reg &= ~clkmgr_bit(clock);
    }
    clkmgr_write(clkmgr, CLKMGR_CLK_ENABLES_REG, reg);
}

bool clkmgr_hintable_clock_get_hint(clkmgr_t clkmgr, size_t clock)
{
    return (clkmgr_read(clkmgr, CLKMGR_CLK_HINTS_REG) & clkmgr_bit(clock)) != 0;
}

void clkmgr_hintable_clock_set_hint(clkmgr_t clkmgr, size_t clock, bool enabled)
{
    uint32_t reg = clkmgr_read(clkmgr, CLKMGR_CLK_HINTS_REG);
    if (enabled) {
        reg |= clkmgr_bit(clock);
    } else {
        reg &= ~clkmgr_bit(clock);
    }
    clkmgr_write(clkmgr, CLKMGR_CLK_HINTS_REG, reg);
}

bool clkmgr_hintable_clock_get_enabled(clkmgr_t clkmgr, size_t clock)
{
    return (clkmgr_read(clkmgr, CLKMGR_CLK_HINTS_STATUS_REG) & clkmgr_bit(clock)) != 0;
}
