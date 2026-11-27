// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/mocha_irq.h"
#include "hal/plic.h"
#include "hal/spi_device.h"
#include <stdbool.h>
#include <stdint.h>

enum {
    mip_read_retry_count = 20u,
};

bool reg_test(plic_t plic)
{
    plic_init(plic);

    plic_interrupt_priority_write(plic, mocha_system_irq_unmapped_28, 2);
    if ((plic_interrupt_priority_read(plic, mocha_system_irq_unmapped_28) != 2)) {
        return false;
    }

    plic_machine_interrupt_enable_set(plic, mocha_system_irq_unmapped_22);
    if (!(plic_machine_interrupt_enable_read(plic) & mocha_system_irq_unmapped_22)) {
        return false;
    }

    plic_machine_interrupt_enable_clear(plic, mocha_system_irq_unmapped_22);
    if (plic_machine_interrupt_enable_read(plic) & mocha_system_irq_unmapped_22) {
        return false;
    }

    plic_supervisor_interrupt_enable_set(plic, mocha_system_irq_unmapped_13);
    if (!(plic_supervisor_interrupt_enable_read(plic) & mocha_system_irq_unmapped_13)) {
        return false;
    }

    plic_supervisor_interrupt_enable_clear(plic, mocha_system_irq_unmapped_13);
    if (plic_supervisor_interrupt_enable_read(plic) & mocha_system_irq_unmapped_13) {
        return false;
    }

    return true;
}

bool spi_device_machine_irq_test(plic_t plic, spi_device_t spi_device)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_spi_device, 3);
    plic_machine_priority_threshold_write(plic, 0);

    spi_device_interrupt_disable_all(spi_device);
    spi_device_interrupt_enable(spi_device, SPI_DEVICE_INTR_TPM_RDFIFO_DROP);

    plic_machine_interrupt_enable_set(plic, mocha_system_irq_spi_device);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    spi_device_interrupt_trigger(spi_device, SPI_DEVICE_INTR_TPM_RDFIFO_DROP);

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
    spi_device_interrupt_clear(spi_device, SPI_DEVICE_INTR_TPM_RDFIFO_DROP);
    plic_machine_interrupt_complete(plic, intr_id);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    return true;
}

bool spi_device_supervisor_irq_test(plic_t plic, spi_device_t spi_device)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_spi_device, 3);
    plic_supervisor_priority_threshold_write(plic, 0);

    spi_device_interrupt_disable_all(spi_device);
    spi_device_interrupt_enable(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);

    plic_supervisor_interrupt_enable_set(plic, mocha_system_irq_spi_device);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_supervisor_external)) {
        return false;
    }

    spi_device_interrupt_trigger(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);

    // Check for mip SEIP is set following the triggered interrupt
    for (size_t i = 0; i < mip_read_retry_count; i++) {
        if (hart_interrupt_any_pending(interrupt_supervisor_external)) {
            break;
        }
    }

    if (!hart_interrupt_any_pending(interrupt_supervisor_external)) {
        return false;
    }

    intr_id = plic_supervisor_interrupt_claim(plic);
    spi_device_interrupt_clear(spi_device, SPI_DEVICE_INTR_UPLOAD_PAYLOAD_OVERFLOW);
    plic_supervisor_interrupt_complete(plic, intr_id);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_supervisor_external)) {
        return false;
    }

    return true;
}

bool test_main()
{
    plic_t plic = mocha_system_plic();
    spi_device_t spi_device = mocha_system_spi_device();

    return reg_test(plic) && spi_device_machine_irq_test(plic, spi_device) &&
           spi_device_supervisor_irq_test(plic, spi_device);
}
