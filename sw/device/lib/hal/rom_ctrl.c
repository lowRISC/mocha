// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/rom_ctrl.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdint.h>

/* Read specific word_idx-th word from ROM memory */
uint32_t read_rom(rom_t rom, uint32_t rel_addr)
{
    return DEV_READ(rom + rel_addr);
}
