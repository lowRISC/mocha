// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/plic.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

uint64_t csr_mip_get()
{
    uint64_t mip;
    __asm__ volatile("csrr %0, mip\n\t" : "=r"(mip));
    return mip;
}

bool reg_test(plic_t plic)
{
    plic_init(plic);

    plic_interrupt_priority_set(plic, 4, 2);
    if ((plic_interrupt_priority_get(plic, 4) & PLIC_PRIO_MASK) != 2) {
        return false;
    }

    plic_machine_interrupt_enable(plic, 22);
    if (!plic_machine_interrupt_enable_get(plic, 22)) {
        return false;
    }

    plic_machine_interrupt_disable(plic, 22);
    if (plic_machine_interrupt_enable_get(plic, 22)) {
        return false;
    }

    plic_supervisor_interrupt_enable(plic, 13);
    if (!plic_supervisor_interrupt_enable_get(plic, 13)) {
        return false;
    }

    plic_supervisor_interrupt_disable(plic, 13);
    if (plic_supervisor_interrupt_enable_get(plic, 13)) {
        return false;
    }

    return true;
}

bool uart_machine_irq_test(plic_t plic, uart_t uart)
{
    uint8_t intr_id;

    const int MIP_RD_RETRY_COUNT = 20;
    const int UART_INTR_ID = 8;
    const uint64_t MEIP_MASK = (1 << 11);

    plic_init(plic);
    plic_interrupt_priority_set(plic, UART_INTR_ID, 3);
    plic_machine_priority_threshold_set(plic, 0);

    uart_interrupt_disable_all(uart);
    uart_interrupt_enable(uart, UART_INTR_RX_FRAME_ERR);

    plic_machine_interrupt_enable(plic, UART_INTR_ID);

    // Check that mip MEIP is clear
    if ((csr_mip_get() & MEIP_MASK) != 0) {
        return false;
    }

    uart_interrupt_trigger(uart, UART_INTR_RX_FRAME_ERR);

    // Check that mip MEIP is set
    // Retry to give time for mip to be updated
    for (int i = 0; (csr_mip_get() & MEIP_MASK) == 0 && i < MIP_RD_RETRY_COUNT; ++i) {
    }

    if ((csr_mip_get() & MEIP_MASK) == 0) {
        return false;
    }

    intr_id = plic_machine_interrupt_claim(plic);
    uart_interrupt_clear(uart, UART_INTR_RX_FRAME_ERR);
    plic_machine_interrupt_complete(plic, intr_id);

    // Check that mip MEIP is clear
    if ((csr_mip_get() & MEIP_MASK) != 0) {
        return false;
    }

    return true;
}

bool uart_supervisor_irq_test(plic_t plic, uart_t uart)
{
    uint8_t intr_id;

    const int MIP_RD_RETRY_COUNT = 20;
    const int UART_INTR_ID = 8;
    const uint64_t SEIP_MASK = (1 << 9);

    plic_init(plic);
    plic_interrupt_priority_set(plic, UART_INTR_ID, 3);
    plic_supervisor_priority_threshold_set(plic, 0);

    uart_interrupt_disable_all(uart);
    uart_interrupt_enable(uart, UART_INTR_RX_TIMEOUT);

    plic_supervisor_interrupt_enable(plic, UART_INTR_ID);

    // Check that mip SEIP is clear
    if ((csr_mip_get() & SEIP_MASK) != 0) {
        return false;
    }

    uart_interrupt_trigger(uart, UART_INTR_RX_TIMEOUT);

    // Check that mip SEIP is set
    // Retry to give time for mip to be updated
    for (int i = 0; (csr_mip_get() & SEIP_MASK) == 0 && i < MIP_RD_RETRY_COUNT; ++i) {
    }

    if ((csr_mip_get() & SEIP_MASK) == 0) {
        return false;
    }

    intr_id = plic_supervisor_interrupt_claim(plic);
    uart_interrupt_clear(uart, UART_INTR_RX_TIMEOUT);
    plic_supervisor_interrupt_complete(plic, intr_id);

    // Check that mip SEIP is clear
    if ((csr_mip_get() & SEIP_MASK) != 0) {
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
