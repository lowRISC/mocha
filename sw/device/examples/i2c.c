// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdint.h>

int main(void)
{
    i2c_t i2c = mocha_system_i2c();
    uart_t uart = mocha_system_uart();
    timer_t timer = mocha_system_timer();
    i2c_init(i2c);
    uart_init(uart);
    timer_init(timer);

    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); // 1 tick/us
    timer_enable(timer);

    uprintf(uart, "Hello i2c Mocha!\n");

    while (true) {
        timer_busy_sleep(timer, 1000);

        // Read current temperature from an AS6212 I^2C-bus sensor and print the value
        if (i2c_write_byte(i2c, 0x48u, 0u)) { // select TVAL reg; also a presence check
            uint16_t sensor_reading = i2c_read_byte(i2c, 0x48u); // read TVAl reg
            if (sensor_reading != 0xFF) { // only print if we get a non-error value
                uprintf(uart, "Temperature: 0x%x degC\n",
                        (sensor_reading << 1)); // no decimal printf
            }
        }
    }

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
