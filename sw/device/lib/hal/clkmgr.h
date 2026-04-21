// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define CLKMGR_ALERT_TEST_REG       (0x00)
#define CLKMGR_JITTER_REGWEN_REG    (0x10)
#define CLKMGR_JITTER_ENABLE_REG    (0x14)
#define CLKMGR_CLK_ENABLES_REG      (0x18)
#define CLKMGR_CLK_HINTS_REG        (0x1c)
#define CLKMGR_CLK_HINTS_STATUS_REG (0x20)

#define CLKMGR_GATEABLE_CLOCK_IO_PERI (0u)
#define CLKMGR_HINTABLE_CLOCK_MAIN    (0u)

typedef void *clkmgr_t;

#define CLKMGR_FROM_BASE_ADDR(addr) ((clkmgr_t)(addr))

bool clkmgr_gateable_clock_get_enabled(clkmgr_t clkmgr, size_t clock);
void clkmgr_gateable_clock_set_enabled(clkmgr_t clkmgr, size_t clock, bool enabled);

bool clkmgr_hintable_clock_get_hint(clkmgr_t clkmgr, size_t clock);
void clkmgr_hintable_clock_set_hint(clkmgr_t clkmgr, size_t clock, bool enabled);
bool clkmgr_hintable_clock_get_enabled(clkmgr_t clkmgr, size_t clock);
