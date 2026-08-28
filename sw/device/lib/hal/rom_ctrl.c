// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/rom_ctrl.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stddef.h>
#include <stdint.h>

/* Read a 32 bit data word from ROM memory */
uint32_t read_rom(rom_t rom, uint32_t rel_addr)
{
    return DEV_READ(rom + rel_addr);
}

rom_ctrl_fatal_alert_cause rom_ctrl_fatal_alert_cause_read(rom_ctrl_t rom_ctrl)
{
    return VOLATILE_READ(rom_ctrl->fatal_alert_cause);
}

uint32_t rom_ctrl_digest_read(rom_ctrl_t rom_ctrl, size_t index)
{
    return VOLATILE_READ(rom_ctrl->digest[index]);
}

uint32_t rom_ctrl_exp_digest_read(rom_ctrl_t rom_ctrl, size_t index)
{
    return VOLATILE_READ(rom_ctrl->exp_digest[index]);
}
