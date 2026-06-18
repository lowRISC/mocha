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
    int i = 0;
    gpio_set_oe_pin(gpio, 0, true);
    gpio_set_oe_pin(gpio, 1, true);
    gpio_set_oe_pin(gpio, 2, true);
    gpio_set_oe_pin(gpio, 3, true);
    uart_init(uart);
    timer_init(timer);

    timer_enable_write(timer, true);

    // Print every 500us forever.
    while (true) {
        timer_busy_sleep_us(timer, 500u);

        uprintf(uart, "Hello CHERI Mocha!\n");
        gpio_write_pin(gpio, i++, 1); // turn on LEDs in sequence
    }

    return -1;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
