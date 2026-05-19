// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "runtime/print.h"

enum {
    mip_read_retry_count = 20u,
};

bool entropy_data_test(entropy_src_t entropy_src)
{
    entropy_src_init(entropy_src);

    // After init, REGWEN should be true
    if (!entropy_src_register_write_enable_read(entropy_src)) {
        return false;
    }

    // Enable module
    entropy_src_module_enable_write(entropy_src, true);

    // After module enable, REGWEN should be false
    if (entropy_src_register_write_enable_read(entropy_src)) {
        return false;
    }

    // After init, FIPS/CC should be disabled
    if (entropy_src_fips_enable_read(entropy_src) != kMultiBitBool4False) {
        return false;
    }

    uint32_t last_entropy_data = 0;
    uint32_t entropy_data;

    // Read boot-time/bypass mode 12 random 32-bit words (384 bits)
    for (int i = 0; i < 12; ++i) {
        while (!entropy_src_interrupt_all_pending(entropy_src, entropy_src_intr_es_entropy_valid)) {
        }

        entropy_data = entropy_src_entropy_data_read(entropy_src);

        entropy_src_interrupt_clear(entropy_src, entropy_src_intr_es_entropy_valid);

        if (entropy_data == last_entropy_data || entropy_data == UINT32_MAX || entropy_data == 0) {
            return false;
        }
        last_entropy_data = entropy_data;
    }

    // No random word available immediately after the first 384-bits
    if (entropy_src_interrupt_all_pending(entropy_src, entropy_src_intr_es_entropy_valid)) {
        return false;
    }

    // Disable module
    entropy_src_module_enable_write(entropy_src, false);

    // After module disable, REGWEN should be true
    if (!entropy_src_register_write_enable_read(entropy_src)) {
        return false;
    }

    // Enable FIPS/CC mode
    entropy_src_fips_enable_write(entropy_src, true);

    if (entropy_src_fips_enable_read(entropy_src) != kMultiBitBool4True) {
        return false;
    }

    // Enable module
    entropy_src_module_enable_write(entropy_src, true);

    // After module enable, REGWEN should be false
    if (entropy_src_register_write_enable_read(entropy_src)) {
        return false;
    }

    // Read FIPS/CC compliant mode random words
    last_entropy_data = 0;
    for (int i = 0; i < 16; ++i) {
        while (!entropy_src_interrupt_all_pending(entropy_src, entropy_src_intr_es_entropy_valid)) {
        }

        entropy_data = entropy_src_entropy_data_read(entropy_src);

        entropy_src_interrupt_clear(entropy_src, entropy_src_intr_es_entropy_valid);

        if (entropy_data == last_entropy_data || entropy_data == UINT32_MAX || entropy_data == 0) {
            return false;
        }
        last_entropy_data = entropy_data;
    }

    // More random words available
    if (!entropy_src_interrupt_all_pending(entropy_src, entropy_src_intr_es_entropy_valid)) {
        return false;
    }

    return true;
}

bool machine_irq_test(entropy_src_t entropy_src, plic_t plic)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_entropy_src, 3);
    plic_machine_priority_threshold_write(plic, 0);

    entropy_src_interrupt_disable_all(entropy_src);
    entropy_src_interrupt_enable_set(entropy_src, entropy_src_intr_es_fatal_err);

    plic_machine_interrupt_enable_set(plic, mocha_system_irq_entropy_src);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    entropy_src_interrupt_force(entropy_src, entropy_src_intr_es_fatal_err);

    // Check that mip MEIP is set following the triggered interrupt
    for (size_t i = 0; i < mip_read_retry_count; i++) {
        if (hart_interrupt_any_pending(interrupt_machine_external)) {
            break;
        }
    }

    if (!hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    intr_id = plic_machine_interrupt_claim(plic);
    entropy_src_interrupt_clear(entropy_src, entropy_src_intr_es_fatal_err);
    plic_machine_interrupt_complete(plic, intr_id);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    return true;
}

bool supervisor_irq_test(entropy_src_t entropy_src, plic_t plic)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_entropy_src, 3);
    plic_supervisor_priority_threshold_write(plic, 0);

    entropy_src_interrupt_disable_all(entropy_src);
    entropy_src_interrupt_enable_set(entropy_src, entropy_src_intr_es_health_test_failed);

    plic_supervisor_interrupt_enable_set(plic, mocha_system_irq_entropy_src);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_supervisor_external)) {
        return false;
    }

    entropy_src_interrupt_force(entropy_src, entropy_src_intr_es_health_test_failed);

    // Check that mip SEIP is set following the triggered interrupt
    for (size_t i = 0; i < mip_read_retry_count; i++) {
        if (hart_interrupt_any_pending(interrupt_supervisor_external)) {
            break;
        }
    }

    if (!hart_interrupt_any_pending(interrupt_supervisor_external)) {
        return false;
    }

    intr_id = plic_supervisor_interrupt_claim(plic);
    entropy_src_interrupt_clear(entropy_src, entropy_src_intr_es_health_test_failed);
    plic_supervisor_interrupt_complete(plic, intr_id);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_supervisor_external)) {
        return false;
    }

    return true;
}

bool test_main()
{
    entropy_src_t entropy_src = mocha_system_entropy_src();
    plic_t plic = mocha_system_plic();

    return entropy_data_test(entropy_src) && machine_irq_test(entropy_src, plic) &&
           supervisor_irq_test(entropy_src, plic);
}
