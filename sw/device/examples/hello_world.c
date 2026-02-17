// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/frame_buffer.h"
#include "hal/spi_device.h"
#include "hal/timer.h"
#include "hal/uart.h"
#include <stdint.h>

int main(void)
{
    uart_t uart = mocha_system_uart();
    timer_t timer = mocha_system_timer();
    spi_device_t spi_device = mocha_system_spi_device();
    frame_buffer_t frame_buffer = mocha_system_frame_buffer();
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
    }

    frame_buffer_write_pixel_565(frame_buffer, 0, 0, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 1, 0, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 2, 0, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 3, 0, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 0, 1, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 1, 1, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 2, 1, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 3, 1, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 0, 2, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 1, 2, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 0, 3, 0b11111, 0b111111, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 1, 3, 0b11111, 0b111111, 0b11111);

    frame_buffer_write_pixel_565(frame_buffer, 510, 0, 0b11111, 0, 0);
    frame_buffer_write_pixel_565(frame_buffer, 511, 0, 0b11111, 0, 0);
    frame_buffer_write_pixel_565(frame_buffer, 510, 1, 0b11111, 0, 0);
    frame_buffer_write_pixel_565(frame_buffer, 511, 1, 0b11111, 0, 0);
    frame_buffer_write_pixel_565(frame_buffer, 510, 2, 0b11111, 0, 0);
    frame_buffer_write_pixel_565(frame_buffer, 511, 2, 0b11111, 0, 0);

    frame_buffer_write_pixel_565(frame_buffer, 0, 1019, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 1, 1019, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 0, 1020, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 1, 1020, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 0, 1021, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 1, 1021, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 0, 1022, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 1, 1022, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 2, 1022, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 3, 1022, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 0, 1023, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 1, 1023, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 2, 1023, 0, 0b111111, 0);
    frame_buffer_write_pixel_565(frame_buffer, 3, 1023, 0, 0b111111, 0);

    frame_buffer_write_pixel_565(frame_buffer, 510, 1021, 0, 0, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 511, 1021, 0, 0, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 510, 1022, 0, 0, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 511, 1022, 0, 0, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 510, 1023, 0, 0, 0b11111);
    frame_buffer_write_pixel_565(frame_buffer, 511, 1023, 0, 0, 0b11111);

    for (int i = 0; i < 300; ++i) {
        for (int j = 0; j < 120; ++j) {
            frame_buffer_write_pixel_565(frame_buffer, 75 + i, 75 + j, 0b11111, 0b111111, 0b11111);
        }
    }

    for (int i = 0; i < 32; ++i) {
        for (int j = 0; j < 50; ++j) {
            frame_buffer_write_pixel_565(frame_buffer, 100 + j, 100 + i, i, 0, 0);
        }
    }

    for (int i = 0; i < 64; ++i) {
        for (int j = 0; j < 50; ++j) {
            frame_buffer_write_pixel_565(frame_buffer, 200 + j, 100 + i, 0, i, 0);
        }
    }

    for (int i = 0; i < 32; ++i) {
        for (int j = 0; j < 50; ++j) {
            frame_buffer_write_pixel_565(frame_buffer, 300 + j, 100 + i, 0, 0, i);
        }
    }

    // Trying out simulation exit.
    uart_puts(uart, "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7");
    uart_puts(uart, "This should not be printed in simulation.\r\n");

    // Poll and process SPI command
    spi_device_cmd_t cmd;
    while (1) {
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
            uart_puts(uart, " addr: 0x");
            uart_put_uint32_hex(uart, cmd.address);
        }

        if (cmd.payload_byte_count > 0) {
            uart_puts(uart, " payload_bytes: 0x");
            uart_put_uint32_hex(uart, (uint32_t)cmd.payload_byte_count);

            uint32_t payload_word_count = ((uint32_t)cmd.payload_byte_count) / sizeof(uint32_t);
            if ((cmd.payload_byte_count % sizeof(uint32_t)) != 0) {
                ++payload_word_count;
            }

            uart_puts(uart, " payload:");

            uint32_t word;
            for (uint32_t i = 0; i < payload_word_count; ++i) {
                word = spi_device_flash_payload_buffer_read(spi_device, i * sizeof(uint32_t));
                spi_device_flash_read_buffer_write(spi_device, cmd.address + i * sizeof(uint32_t),
                                                   word);

                uart_puts(uart, " 0x");
                uart_put_uint32_hex(uart, word);
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
