// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/mocha_irq.h"
#include "hal/plic.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

enum {
    mip_read_retry_count = 20u,
};

bool reg_test(plic_t plic)
{
    plic_init(plic);

    plic_interrupt_priority_write(plic, mocha_system_irq_unmapped_4, 2);
    if ((plic_interrupt_priority_read(plic, mocha_system_irq_unmapped_4) != 2)) {
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

bool uart_machine_irq_test(plic_t plic, uart_t uart)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_uart, 3);
    plic_machine_priority_threshold_write(plic, 0);

    uart_interrupt_enable_write(uart, uart_intr_rx_frame_err);

    plic_machine_interrupt_enable_set(plic, mocha_system_irq_uart);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    uart_interrupt_force(uart, uart_intr_rx_frame_err);

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
    uart_interrupt_clear(uart, uart_intr_rx_frame_err);
    plic_machine_interrupt_complete(plic, intr_id);

    // Check that mip MEIP is clear
    if (hart_interrupt_any_pending(interrupt_machine_external)) {
        return false;
    }

    return true;
}

bool uart_supervisor_irq_test(plic_t plic, uart_t uart)
{
    uint32_t intr_id;

    plic_init(plic);
    plic_interrupt_priority_write(plic, mocha_system_irq_uart, 3);
    plic_supervisor_priority_threshold_write(plic, 0);

    uart_interrupt_enable_write(uart, uart_intr_rx_timeout);

    plic_supervisor_interrupt_enable_set(plic, mocha_system_irq_uart);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    uart_interrupt_force(uart, uart_intr_rx_timeout);

    // Check for mip SEIP is set following the triggered interrupt
    for (size_t i = 0; i < mip_read_retry_count; i++) {
        if (hart_interrupt_any_pending(interrupt_software_external)) {
            break;
        }
    }

    if (!hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    intr_id = plic_supervisor_interrupt_claim(plic);
    uart_interrupt_clear(uart, uart_intr_rx_timeout);
    plic_supervisor_interrupt_complete(plic, intr_id);

    // Check that mip SEIP is clear
    if (hart_interrupt_any_pending(interrupt_software_external)) {
        return false;
    }

    return true;
}

bool test_main(uart_t console)
{
    plic_t plic = mocha_system_plic();

    return reg_test(plic) && uart_machine_irq_test(plic, console) &&
           uart_supervisor_irq_test(plic, console);
}
