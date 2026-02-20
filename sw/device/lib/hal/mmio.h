// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// MMIO macros.

#pragma once

#include <stdint.h>

#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = (val))
#define DEV_READ(addr)       (*((volatile uint32_t *)(addr)))

#define DEV_WRITE8(addr, val)  (*((volatile uint8_t *)(addr)) = (val))
#define DEV_READ8(addr)        (*((volatile uint8_t *)(addr)))
#define DEV_WRITE16(addr, val) (*((volatile uint16_t *)(addr)) = (val))
#define DEV_READ16(addr)       (*((volatile uint16_t *)(addr)))
#define DEV_WRITE64(addr, val) (*((volatile uint64_t *)(addr)) = (val))
#define DEV_READ64(addr)       (*((volatile uint64_t *)(addr)))

#define VOLATILE_READ(reg)       (*((volatile __typeof((reg)) *)&(reg)))
#define VOLATILE_WRITE(reg, val) (*((volatile __typeof((reg)) *)&(reg)) = (__typeof((reg)))(val))
