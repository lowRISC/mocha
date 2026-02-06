// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// MMIO macros.

#pragma once

#include <stdint.h>

#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr)       (*((volatile uint32_t *)(addr)))

#define DEV_READ64(addr) (*((volatile uint64_t *)(addr)))
