// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/clkmgr.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

static bool test_gateable_clock(clkmgr_t clkmgr)
{
    bool initial = clkmgr_gateable_clock_get_enabled(clkmgr, CLKMGR_GATEABLE_CLOCK_IO_PERI);
    bool toggled = !initial;

    clkmgr_gateable_clock_set_enabled(clkmgr, CLKMGR_GATEABLE_CLOCK_IO_PERI, toggled);
    if (clkmgr_gateable_clock_get_enabled(clkmgr, CLKMGR_GATEABLE_CLOCK_IO_PERI) != toggled) {
        return false;
    }

    clkmgr_gateable_clock_set_enabled(clkmgr, CLKMGR_GATEABLE_CLOCK_IO_PERI, initial);
    return clkmgr_gateable_clock_get_enabled(clkmgr, CLKMGR_GATEABLE_CLOCK_IO_PERI) == initial;
}

static bool test_hintable_clock(clkmgr_t clkmgr)
{
    bool initial = clkmgr_hintable_clock_get_hint(clkmgr, CLKMGR_HINTABLE_CLOCK_MAIN);
    bool toggled = !initial;

    clkmgr_hintable_clock_set_hint(clkmgr, CLKMGR_HINTABLE_CLOCK_MAIN, toggled);
    if (clkmgr_hintable_clock_get_hint(clkmgr, CLKMGR_HINTABLE_CLOCK_MAIN) != toggled) {
        return false;
    }

    if (toggled && !clkmgr_hintable_clock_get_enabled(clkmgr, CLKMGR_HINTABLE_CLOCK_MAIN)) {
        return false;
    }

    clkmgr_hintable_clock_set_hint(clkmgr, CLKMGR_HINTABLE_CLOCK_MAIN, initial);
    return clkmgr_hintable_clock_get_hint(clkmgr, CLKMGR_HINTABLE_CLOCK_MAIN) == initial;
}

bool test_main()
{
    clkmgr_t clkmgr = mocha_system_clkmgr();
    return test_gateable_clock(clkmgr) && test_hintable_clock(clkmgr);
}
