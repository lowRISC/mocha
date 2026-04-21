// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/clkmgr.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool clkmgr_gateable_clock_get_enabled(clkmgr_t clkmgr, size_t clock)
{
    if (clock != CLKMGR_GATEABLE_CLOCK_IO_PERI) {
        return false;
    }
    return VOLATILE_READ(clkmgr->clk_enables).clk_io_peri_en;
}

void clkmgr_gateable_clock_set_enabled(clkmgr_t clkmgr, size_t clock, bool enabled)
{
    if (clock != CLKMGR_GATEABLE_CLOCK_IO_PERI) {
        return;
    }
    clkmgr_clk_enables clk_enables = VOLATILE_READ(clkmgr->clk_enables);
    clk_enables.clk_io_peri_en = enabled;
    VOLATILE_WRITE(clkmgr->clk_enables, clk_enables);
}

bool clkmgr_hintable_clock_get_hint(clkmgr_t clkmgr, size_t clock)
{
    if (clock != CLKMGR_HINTABLE_CLOCK_MAIN) {
        return false;
    }
    return VOLATILE_READ(clkmgr->clk_hints).clk_main_hint_hint;
}

void clkmgr_hintable_clock_set_hint(clkmgr_t clkmgr, size_t clock, bool enabled)
{
    if (clock != CLKMGR_HINTABLE_CLOCK_MAIN) {
        return;
    }
    clkmgr_clk_hints clk_hints = VOLATILE_READ(clkmgr->clk_hints);
    clk_hints.clk_main_hint_hint = enabled;
    VOLATILE_WRITE(clkmgr->clk_hints, clk_hints);
}

bool clkmgr_hintable_clock_get_enabled(clkmgr_t clkmgr, size_t clock)
{
    if (clock != CLKMGR_HINTABLE_CLOCK_MAIN) {
        return false;
    }
    return VOLATILE_READ(clkmgr->clk_hints_status).clk_main_hint_val;
}
