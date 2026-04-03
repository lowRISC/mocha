// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/plic.h"
#include "hal/spi_device.h"
#include <stdbool.h>
#include <stdint.h>

enum {
    mip_read_retry_count = 20u,
};

bool cmd_filter_readback_test(spi_device_t spi_device, uint32_t offset)
{
    spi_device_cmd_filter_set(spi_device, offset, 0x55555555);
    if (spi_device_cmd_filter_get(spi_device, offset) != 0x55555555) {
        return false;
    }

    spi_device_cmd_filter_set(spi_device, offset, 0xAAAAAAAA);
    if (spi_device_cmd_filter_get(spi_device, offset) != 0xAAAAAAAA) {
        return false;
    }

    return true;
}

bool cmd_info_readback_test(spi_device_t spi_device, uint32_t offset)
{
    const uint32_t CMD_INFO_RESET_MASK = 0x83FFFFFF;
    spi_device_cmd_info_set_raw(spi_device, offset, 0xAAAAAAAA & CMD_INFO_RESET_MASK);
    if ((spi_device_cmd_info_get(spi_device, offset) & CMD_INFO_RESET_MASK) !=
        (0xAAAAAAAA & CMD_INFO_RESET_MASK)) {
        return false;
    }

    spi_device_cmd_info_set_raw(spi_device, offset, 0x55555555 & CMD_INFO_RESET_MASK);
    if ((spi_device_cmd_info_get(spi_device, offset) & CMD_INFO_RESET_MASK) !=
        (0x55555555 & CMD_INFO_RESET_MASK)) {
        return false;
    }

    return true;
}

bool reg_test(spi_device_t spi_device)
{
    spi_device_4b_addr_mode_enable_set(spi_device, true);
    if (!spi_device_4b_addr_mode_enable_get(spi_device)) {
        return false;
    }

    spi_device_4b_addr_mode_enable_set(spi_device, false);
    if (spi_device_4b_addr_mode_enable_get(spi_device)) {
        return false;
    }

    spi_device_jedec_cc_set(spi_device, 0xE1, 0x45);
    if ((spi_device_jedec_cc_get(spi_device) & 0xFFFF) != 0x45E1) {
        return false;
    }

    spi_device_jedec_id_set_raw(spi_device, 0x555555);
    if ((spi_device_jedec_id_get(spi_device) & 0xFFFFFF) != 0x555555) {
        return false;
    }

    spi_device_jedec_id_set_raw(spi_device, 0xAAAAAA);
    if ((spi_device_jedec_id_get(spi_device) & 0xFFFFFF) != 0xAAAAAA) {
        return false;
    }

    spi_device_mailbox_addr_set(spi_device, 0x5555AAAA);
    if (spi_device_mailbox_addr_get(spi_device) != 0x5555AAAA) {
        return false;
    }

    spi_device_mailbox_addr_set(spi_device, 0xAAAA5555);
    if (spi_device_mailbox_addr_get(spi_device) != 0xAAAA5555) {
        return false;
    }

    if (!(cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_0_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_1_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_2_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_3_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_4_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_5_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_6_REG) &&
          cmd_filter_readback_test(spi_device, SPI_DEVICE_CMD_FILTER_7_REG))) {
        return false;
    }

    if (!(cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_0_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_1_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_2_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_3_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_20_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_21_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_22_REG) &&
          cmd_info_readback_test(spi_device, SPI_DEVICE_CMD_INFO_23_REG))) {
        return false;
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
    spi_device_interrupt_enable(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);

    plic_machine_interrupt_enable_set(plic, mocha_system_irq_spi_device);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    spi_device_interrupt_trigger(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);

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
    spi_device_interrupt_clear(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);
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
    spi_device_interrupt_enable(spi_device, SPI_DEVICE_INTR_READBUF_FLIP);

    plic_supervisor_interrupt_enable_set(plic, mocha_system_irq_spi_device);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    spi_device_interrupt_trigger(spi_device, SPI_DEVICE_INTR_READBUF_FLIP);

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
    spi_device_interrupt_clear(spi_device, SPI_DEVICE_INTR_READBUF_FLIP);
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
