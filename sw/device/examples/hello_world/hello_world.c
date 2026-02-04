// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include <stdint.h>

int main(void)
{
    uart_t uart = mocha_system_uart();
    timer_t timer = mocha_system_timer();
    uart_init(uart);
    timer_init(timer);
    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); // 1 tick/us
    timer_enable(timer);

    uart_puts(uart, "Hello CHERI Mocha!\n");

    // Print every 100us
    for (int i = 0; i < 4; ++i) {
        timer_busy_sleep(timer, 100);

        uart_puts(uart, "timer 100us\n");
    }

    // Trying out simulation exit.
    uart_puts(uart, "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");
    uart_puts(uart, "This should not be printed in simulation.\r\n");

    // Print every 1s
    while (1) {
        timer_busy_sleep(timer, 1000000);

        uart_puts(uart, "timer 1s\n");
    }

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
