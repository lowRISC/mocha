// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "autogen/entropy_src.h"
#include "hal/multibit.h"
#include <stdbool.h>
#include <stdint.h>

/* initialisation */
void entropy_src_init(entropy_src_t entropy_src);

/* interrupts */
entropy_src_intr entropy_src_interrupt_enable_read(entropy_src_t entropy_src);
void entropy_src_interrupt_enable_write(entropy_src_t entropy_src, entropy_src_intr intrs);
void entropy_src_interrupt_enable_set(entropy_src_t entropy_src, entropy_src_intr intrs);
void entropy_src_interrupt_enable_clear(entropy_src_t entropy_src, entropy_src_intr intrs);
void entropy_src_interrupt_force(entropy_src_t entropy_src, entropy_src_intr intrs);
void entropy_src_interrupt_clear(entropy_src_t entropy_src, entropy_src_intr intrs);
void entropy_src_interrupt_disable_all(entropy_src_t entropy_src);
bool entropy_src_interrupt_all_pending(entropy_src_t entropy_src, entropy_src_intr intrs);

bool entropy_src_register_write_enable_read(entropy_src_t entropy_src);
void entropy_src_module_enable_write(entropy_src_t entropy_src, bool enable);
uint32_t entropy_src_module_enable_read(entropy_src_t entropy_src);
void entropy_src_conf_write(entropy_src_t entropy_src, entropy_src_conf conf);
entropy_src_conf entropy_src_conf_read(entropy_src_t entropy_src);
void entropy_src_fips_enable_write(entropy_src_t entropy_src, bool enable);
uint32_t entropy_src_fips_enable_read(entropy_src_t entropy_src);
void entropy_src_entropy_data_reg_enable_write(entropy_src_t entropy_src, bool enable);
uint32_t entropy_src_entropy_data_reg_enable_read(entropy_src_t entropy_src);
void entropy_src_entropy_control_write(entropy_src_t entropy_src,
                                       entropy_src_entropy_control entropy_control);
entropy_src_entropy_control entropy_src_entropy_control_read(entropy_src_t entropy_src);
uint32_t entropy_src_entropy_data_read(entropy_src_t entropy_src);
