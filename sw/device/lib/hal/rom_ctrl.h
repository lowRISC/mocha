// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/rom_ctrl.h"
#include "builtin.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef void *rom_t;

uint32_t read_rom(rom_t rom, uint32_t rel_addr);

/* Reasons a fatal alert was raised: a failure in the ROM checker, or a bus
 * integrity error. The bits are sticky and cannot be cleared once set. */
rom_ctrl_fatal_alert_cause rom_ctrl_fatal_alert_cause_read(rom_ctrl_t rom_ctrl);

/* One word of the digest computed by KMAC over the boot ROM contents. */
uint32_t rom_ctrl_digest_read(rom_ctrl_t rom_ctrl, size_t index);

/* One word of the expected digest, stored in the top words of the boot ROM
 * image. rom_ctrl compares this against the digest KMAC computed. */
uint32_t rom_ctrl_exp_digest_read(rom_ctrl_t rom_ctrl, size_t index);
