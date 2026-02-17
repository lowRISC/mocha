// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/gpio.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdint.h>

int main(void)
{
    gpio_t gpio = mocha_system_gpio();
    uart_t uart = mocha_system_uart();
    timer_t timer = mocha_system_timer();
    gpio_set_oe_pin(gpio, 0, true);
    gpio_set_oe_pin(gpio, 1, true);
    gpio_set_oe_pin(gpio, 2, true);
    gpio_set_oe_pin(gpio, 3, true);
    uart_init(uart);
    timer_init(timer);

    timer_enable(timer);

    uprintf(uart, "Hello CHERI Mocha!\n");

    // Print every 100us
    for (int i = 0; i < 4; ++i) {
        timer_busy_sleep_us(timer, 100u);

        uprintf(uart, "timer 100us\n");
        gpio_write_pin(gpio, i, 1); // turn on LEDs in sequence
    }

    // Trying out simulation exit.
    uprintf(uart, "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");
    uprintf(uart, "This should not be printed in simulation.\r\n");

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
