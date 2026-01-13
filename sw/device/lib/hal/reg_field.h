// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Register field macros.

#pragma once

#include <stdint.h>

static inline uint32_t reg32_field(uint8_t upper, uint8_t lower, uint32_t value)
{
    if (32 <= upper || upper < lower) {
        return 0;
    }
    const uint32_t mask = (1 << (upper - lower + 1)) - 1;
    return (mask & value) << lower;
}
