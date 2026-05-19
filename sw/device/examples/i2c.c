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
    i2c_init(i2c, i2c_speed_mode_standard);
    uart_init(uart);
    timer_init(timer);
    timer_enable_write(timer, true);

    // Enable I2C in controller mode
    i2c_enable_controller_mode(i2c);

    uprintf(uart, "Hello i2c Mocha!\n");

    while (true) {
        timer_busy_sleep_us(timer, 1000u);

        uint8_t w_data = 0;
        // Read current temperature from an AS6212 I^2C-bus sensor and print the value
        i2c_write_bytes(i2c, 0x48u, &w_data, 1);
        if (i2c_wait_write_finish(i2c)) { // select TVAL reg; also a presence check
            i2c_read_bytes(i2c, 0x48u, 1);
            if (i2c_wait_read_finish(i2c)) {
                uint16_t sensor_reading = i2c_rdata_byte(i2c); // read TVAl reg
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
