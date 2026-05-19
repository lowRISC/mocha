// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/entropy_src.h"
#include "hal/mmio.h"
#include "runtime/print.h"

void entropy_src_init(entropy_src_t entropy_src)
{
    // Disable module so that config registers are writable
    entropy_src_module_enable_write(entropy_src, false);

    // Set default config
    entropy_src_conf conf = {
        .fips_enable = kMultiBitBool4False, // Disable FIPS/CC mode
        .fips_flag = kMultiBitBool4False, // Disable FIPS/CC mode
        .rng_fips = kMultiBitBool4False, // Disable conservative operation mode
        .rng_bit_enable = kMultiBitBool4False, // Disable single bit mode
        .threshold_scope = kMultiBitBool4False, // Use by-line test scope
        .entropy_data_reg_enable = kMultiBitBool4True, // Enable reading from ENTROPY_DATA register
        .rng_bit_sel = 0 // Unused
    };
    entropy_src_conf_write(entropy_src, conf);

    // Set default entropy control
    entropy_src_entropy_control entropy_control = {
        .es_route = kMultiBitBool4True, // Route entropy to ENTROPY_DATA register
        .es_type = kMultiBitBool4False // Enable hardware conditioning
    };
    entropy_src_entropy_control_write(entropy_src, entropy_control);
}

entropy_src_intr entropy_src_interrupt_enable_read(entropy_src_t entropy_src)
{
    return VOLATILE_READ(entropy_src->intr_enable);
}

void entropy_src_interrupt_enable_write(entropy_src_t entropy_src, entropy_src_intr intrs)
{
    VOLATILE_WRITE(entropy_src->intr_enable, intrs);
}

void entropy_src_interrupt_enable_set(entropy_src_t entropy_src, entropy_src_intr intrs)
{
    entropy_src_intr intr_enable = entropy_src_interrupt_enable_read(entropy_src);
    intr_enable |= intrs;
    entropy_src_interrupt_enable_write(entropy_src, intr_enable);
}

void entropy_src_interrupt_enable_clear(entropy_src_t entropy_src, entropy_src_intr intrs)
{
    entropy_src_intr intr_enable = entropy_src_interrupt_enable_read(entropy_src);
    intr_enable &= ~intrs;
    entropy_src_interrupt_enable_write(entropy_src, intr_enable);
}

void entropy_src_interrupt_force(entropy_src_t entropy_src, entropy_src_intr intrs)
{
    VOLATILE_WRITE(entropy_src->intr_test, intrs);
}

void entropy_src_interrupt_clear(entropy_src_t entropy_src, entropy_src_intr intrs)
{
    VOLATILE_WRITE(entropy_src->intr_state, intrs);
}

void entropy_src_interrupt_disable_all(entropy_src_t entropy_src)
{
    /* NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange) */
    VOLATILE_WRITE(entropy_src->intr_enable, 0);
}

bool entropy_src_interrupt_all_pending(entropy_src_t entropy_src, entropy_src_intr intrs)
{
    return (VOLATILE_READ(entropy_src->intr_state) & intrs) == intrs;
}

bool entropy_src_register_write_enable_read(entropy_src_t entropy_src)
{
    entropy_src_regwen regwen = VOLATILE_READ(entropy_src->regwen);
    return regwen.regwen;
}

void entropy_src_module_enable_write(entropy_src_t entropy_src, bool enable)
{
    entropy_src_module_enable module_enable = {
        .module_enable = enable ? kMultiBitBool4True : kMultiBitBool4False
    };
    VOLATILE_WRITE(entropy_src->module_enable, module_enable);
}

uint32_t entropy_src_module_enable_read(entropy_src_t entropy_src)
{
    entropy_src_module_enable module_enable = VOLATILE_READ(entropy_src->module_enable);
    return module_enable.module_enable;
}

void entropy_src_conf_write(entropy_src_t entropy_src, entropy_src_conf conf)
{
    VOLATILE_WRITE(entropy_src->conf, conf);
}

entropy_src_conf entropy_src_conf_read(entropy_src_t entropy_src)
{
    return VOLATILE_READ(entropy_src->conf);
}

void entropy_src_fips_enable_write(entropy_src_t entropy_src, bool enable)
{
    entropy_src_conf conf = entropy_src_conf_read(entropy_src);
    conf.fips_enable = enable ? kMultiBitBool4True : kMultiBitBool4False;
    conf.fips_flag = enable ? kMultiBitBool4True : kMultiBitBool4False;
    entropy_src_conf_write(entropy_src, conf);
}

uint32_t entropy_src_fips_enable_read(entropy_src_t entropy_src)
{
    entropy_src_conf conf = entropy_src_conf_read(entropy_src);
    return conf.fips_enable;
}

void entropy_src_entropy_data_reg_enable_write(entropy_src_t entropy_src, bool enable)
{
    entropy_src_conf conf = entropy_src_conf_read(entropy_src);
    conf.entropy_data_reg_enable = enable ? kMultiBitBool4True : kMultiBitBool4False;
    entropy_src_conf_write(entropy_src, conf);
}

uint32_t entropy_src_entropy_data_reg_enable_read(entropy_src_t entropy_src)
{
    entropy_src_conf conf = entropy_src_conf_read(entropy_src);
    return conf.entropy_data_reg_enable;
}

void entropy_src_entropy_control_write(entropy_src_t entropy_src,
                                       entropy_src_entropy_control entropy_control)
{
    VOLATILE_WRITE(entropy_src->entropy_control, entropy_control);
}

entropy_src_entropy_control entropy_src_entropy_control_read(entropy_src_t entropy_src)
{
    return VOLATILE_READ(entropy_src->entropy_control);
}

uint32_t entropy_src_entropy_data_read(entropy_src_t entropy_src)
{
    return VOLATILE_READ(entropy_src->entropy_data);
}
