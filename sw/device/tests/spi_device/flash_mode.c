// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/spi_device.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

bool spi_cmd_poll_test(spi_device_t spi_device, uart_t uart)
{
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

    return true;
}

bool test_main(uart_t console)
{
    spi_device_t spi_device = mocha_system_spi_device();

    spi_device_init(spi_device);

    return spi_cmd_poll_test(spi_device, console);
}
