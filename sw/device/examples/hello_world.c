// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/gpio.h"
#include "hal/i2c.h"
#include "hal/mocha.h"
#include "hal/spi_device.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdint.h>

int main(void)
{
    gpio_t gpio = mocha_system_gpio();
    i2c_t i2c = mocha_system_i2c();
    uart_t uart = mocha_system_uart();
    timer_t timer = mocha_system_timer();
    spi_device_t spi_device = mocha_system_spi_device();
    gpio_set_oe_pin(gpio, 0, true);
    gpio_set_oe_pin(gpio, 1, true);
    gpio_set_oe_pin(gpio, 2, true);
    gpio_set_oe_pin(gpio, 3, true);
    i2c_init(i2c);
    uart_init(uart);
    timer_init(timer);
    spi_device_init(spi_device);

    timer_set_prescale_step(timer, (SYSCLK_FREQ / 1000000) - 1, 1); // 1 tick/us
    timer_enable(timer);

    uart_puts(uart, "Hello CHERI Mocha!\n");

    // Print every 100us
    for (int i = 0; i < 4; ++i) {
        timer_busy_sleep(timer, 100);

        uart_puts(uart, "timer 100us\n");
        gpio_write_pin(gpio, i, 1); // turn on LEDs in sequence
    }

    // Read current temperature from an AS6212 I^2C-bus sensor and print the value
    if (i2c_write_byte(i2c, 0x48u, 0u)) { // select TVAL reg; also a presence check
        uint16_t sensor_reading = i2c_read_byte(i2c, 0x48u); // read TVAl reg
        if (sensor_reading != 0xFF) { // only print if we get a non-error value
            uprintf(uart, "Temperature: 0x%x degC\n", (sensor_reading << 1)); // no decimal printf
        }
    }

    // Trying out simulation exit.
    uart_puts(uart, "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");
    uart_puts(uart, "This should not be printed in simulation.\r\n");

    // Poll and process SPI command
    spi_device_cmd_t cmd;
    uint8_t loop_count = 1;
    while (1) {
        // Count loops using the user LEDs - just to make some use of them
        gpio_write_pin(gpio, 0, !!(loop_count & 0x1));
        gpio_write_pin(gpio, 1, !!(loop_count & 0x2));
        gpio_write_pin(gpio, 2, !!(loop_count & 0x4));
        gpio_write_pin(gpio, 3, !!(loop_count & 0x8));
        loop_count++;

        // Now process SPI command (if any)
        cmd = spi_device_cmd_get(spi_device);
        if (cmd.status != 0) {
            uart_puts(uart, "SPI payload overflow\n");
            spi_device_flash_status_set(spi_device, 0);
            continue;
        }

        switch (cmd.opcode) {
        case SPI_DEVICE_OPCODE_CHIP_ERASE:
            uart_puts(uart, "SPI CHIP ERASE");
            break;
        case SPI_DEVICE_OPCODE_SECTOR_ERASE:
            uart_puts(uart, "SPI SECTOR ERASE");
            break;
        case SPI_DEVICE_OPCODE_PAGE_PROGRAM:
            uart_puts(uart, "SPI PAGE PROGRAM");
            break;
        case SPI_DEVICE_OPCODE_RESET:
            uart_puts(uart, "SPI RESET");
            break;
        default:
            uart_puts(uart, "SPI ??");
            break;
        }

        if (cmd.address != UINT32_MAX) {
            uprintf(uart, " addr: 0x%x\n", cmd.address);
        }

        if (cmd.payload_byte_count > 0) {
            uprintf(uart, "payload bytes: 0x%x\n", cmd.payload_byte_count);
            uint32_t payload_word_count = ((uint32_t)cmd.payload_byte_count) / sizeof(uint32_t);
            if ((cmd.payload_byte_count % sizeof(uint32_t)) != 0) {
                ++payload_word_count;
            }

            uart_puts(uart, "payload data:\n");

            uint32_t word;
            for (uint32_t i = 0; i < payload_word_count; ++i) {
                word = spi_device_flash_payload_buffer_read(spi_device, i * sizeof(uint32_t));
                spi_device_flash_read_buffer_write(spi_device, cmd.address + i * sizeof(uint32_t),
                                                   word);
                uprintf(uart, "0x%x\n", word);
            }
        }

        uart_puts(uart, "\n");

        spi_device_flash_status_set(spi_device, 0);
    }

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
