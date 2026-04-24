// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "builtin.h"
#include <stdbool.h>
#include <stdint.h>


#define ROM_CTRL_REG      (0x0)
#define FATAL_ALERT_CAUSE (0x4)

typedef void *rom_ctrl_t;
typedef void *rom_t;

uint32_t read_rom(rom_t rom, uint32_t rel_addr);
