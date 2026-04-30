// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "builtin.h"
#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/plic.h"
#include "hal/spi_device.h"
#include <stdbool.h>
#include <stdint.h>

enum {
    mip_read_retry_count = 20u,
};

bool cmd_filter_readback_test(spi_device_t spi_device, size_t index)
{
    spi_device_cmd_filter_enable_set(spi_device, index, 0x55555555u);
    if (spi_device_cmd_filter_get(spi_device, index) != 0x55555555u) {
        return false;
    }

    spi_device_cmd_filter_enable_set(spi_device, index, 0xaaaaaaaau);
    if (spi_device_cmd_filter_get(spi_device, index) != 0xaaaaaaaau) {
        return false;
    }

    return true;
}

bool cmd_info_readback_test(spi_device_t spi_device, size_t index)
{
    union {
        uint32_t raw;
        spi_device_cmd_info cmdinfo;
    } cmd_info = { .cmdinfo = {
                       .opcode = 0xffu,
                       .addr_mode = 0x3u,
                       .addr_swap_en = true,
                       .mbyte_en = true,
                       .dummy_size = 0x7u,
                       .dummy_en = true,
                       .payload_en = 0xfu,
                       .payload_dir = true,
                       .payload_swap_en = true,
                       .read_pipeline_mode = 0x3u,
                       .upload = true,
                       .busy = true,
                       .valid = true,
                   } };

    union {
        uint32_t raw;
        spi_device_cmd_info cmdinfo;
    } cmd_info_readback;

    spi_device_cmd_info_set(spi_device, cmd_info.cmdinfo, index);
    cmd_info_readback.cmdinfo = spi_device_cmd_info_get(spi_device, index);

    if (cmd_info.raw != cmd_info_readback.raw) {
        return false;
    }

    return true;
}

bool reg_test(spi_device_t spi_device)
{
    spi_device_4b_addr_mode_enable_set_unchecked(spi_device, true);
    if (!spi_device_4b_addr_mode_enable_get(spi_device)) {
        return false;
    }

    spi_device_4b_addr_mode_enable_set_unchecked(spi_device, false);
    if (spi_device_4b_addr_mode_enable_get(spi_device)) {
        return false;
    }

    spi_device_jedec_cc jedec_cc = {
        .cc = 0xe1,
        .num_cc = 0x45,
    };
    spi_device_jedec_cc_set(spi_device, jedec_cc);

    spi_device_jedec_cc jedec_cc_readback = spi_device_jedec_cc_get(spi_device);
    if (jedec_cc_readback.cc != jedec_cc.cc || jedec_cc_readback.num_cc != jedec_cc.num_cc) {
        return false;
    }

    spi_device_jedec_id jedec_id = {
        .id = 0x5555,
        .mf = 0x55,
    };
    spi_device_jedec_id_set(spi_device, jedec_id);

    spi_device_jedec_id jedec_id_readback = spi_device_jedec_id_get(spi_device);
    if (jedec_id_readback.id != jedec_id.id || jedec_id_readback.mf != jedec_id.mf) {
        return false;
    }

    spi_device_mailbox_addr_set(spi_device, 0x5555aaaau);
    if (spi_device_mailbox_addr_get(spi_device) != 0x5555aaaau) {
        return false;
    }

    spi_device_mailbox_addr_set(spi_device, 0xaaaa5555u);
    if (spi_device_mailbox_addr_get(spi_device) != 0xaaaa5555u) {
        return false;
    }

    for (size_t i = 0; i < 8; i++) {
        if (!cmd_filter_readback_test(spi_device, i)) {
            return false;
        }
    }

    for (size_t i = 0; i < ARRAY_LEN(spi_device->cmd_info); i++) {
        if (!cmd_info_readback_test(spi_device, i)) {
            return false;
        }
    }

    return true;
}

bool machine_irq_test(spi_device_t spi_device, plic_t plic)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_spi_device, 3);
    plic_machine_priority_threshold_write(plic, 0);

    spi_device_interrupt_disable_all(spi_device);
    spi_device_interrupt_enable(spi_device, spi_device_intr_upload_payload_overflow);

    plic_machine_interrupt_enable_set(plic, mocha_system_irq_spi_device);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    spi_device_interrupt_force(spi_device, spi_device_intr_upload_payload_overflow);

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
    spi_device_interrupt_clear(spi_device, spi_device_intr_upload_payload_overflow);
    plic_machine_interrupt_complete(plic, intr_id);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    return true;
}

bool supervisor_irq_test(spi_device_t spi_device, plic_t plic)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_spi_device, 3);
    plic_supervisor_priority_threshold_write(plic, 0);

    spi_device_interrupt_disable_all(spi_device);
    spi_device_interrupt_enable(spi_device, spi_device_intr_readbuf_flip);

    plic_supervisor_interrupt_enable_set(plic, mocha_system_irq_spi_device);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    spi_device_interrupt_force(spi_device, spi_device_intr_readbuf_flip);

    // Check that mip SEIP is set following the triggered interrupt
    for (size_t i = 0; i < mip_read_retry_count; i++) {
        if (hart_interrupt_any_pending(interrupt_software_external)) {
            break;
        }
    }

    if (!hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    intr_id = plic_supervisor_interrupt_claim(plic);
    spi_device_interrupt_clear(spi_device, spi_device_intr_readbuf_flip);
    plic_supervisor_interrupt_complete(plic, intr_id);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    return true;
}

bool test_main()
{
    spi_device_t spi_device = mocha_system_spi_device();
    plic_t plic = mocha_system_plic();

    spi_device_init(spi_device);

    return reg_test(spi_device) && machine_irq_test(spi_device, plic) &&
           supervisor_irq_test(spi_device, plic);
}
