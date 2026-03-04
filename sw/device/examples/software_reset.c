// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/rstmgr.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdint.h>

int main(void)
{
    uart_t uart = mocha_system_uart();
    rstmgr_t rstmgr = mocha_system_rstmgr();
    uart_init(uart);

    uart_puts(uart, "Mocha software reset test!\n");

    if (rstmgr_software_reset_info_get(rstmgr)) {
        // System was successfully reset by software.
        uart_puts(uart, "Test passed!\n");
        // Trying out simulation exit.
        uart_puts(uart, "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");
        uart_puts(uart, "This should not be printed in simulation.\r\n");
    } else {
        uart_puts(uart, "Requesting system reset from software.\n");
        // Request a reset of the system.
        rstmgr_software_reset_request(rstmgr);
    }

    while (1) {
    }
    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
