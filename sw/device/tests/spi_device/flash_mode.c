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
    spi_device_software_command command;
    while (true) {
        bool success = spi_device_software_command_get(spi_device, &command);
        if (!success) {
            uart_puts(uart, "SPI payload overflow\n");
            spi_device_flash_status status = { 0 };
            spi_device_flash_status_set(spi_device, status);
            continue;
        }

        switch (command.opcode) {
        case spi_device_opcode_chip_erase:
            uart_puts(uart, "SPI CHIP ERASE");
            break;
        case spi_device_opcode_sector_erase:
            uart_puts(uart, "SPI SECTOR ERASE");
            break;
        case spi_device_opcode_page_program:
            uart_puts(uart, "SPI PAGE PROGRAM");
            break;
        case spi_device_opcode_reset:
            uart_puts(uart, "SPI RESET");
            break;
        default:
            uart_puts(uart, "SPI ??");
            break;
        }

        if (command.has_address) {
            uprintf(uart, " addr: 0x%x\n", command.address);
        }

        if (command.payload_byte_count > 0) {
            uprintf(uart, "payload bytes: 0x%x\n", command.payload_byte_count);
            uint32_t payload_word_count = ((uint32_t)command.payload_byte_count) / sizeof(uint32_t);
            if ((command.payload_byte_count % sizeof(uint32_t)) != 0) {
                payload_word_count++;
            }

            uart_puts(uart, "payload data:\n");

            uint32_t word;
            for (uint32_t i = 0; i < payload_word_count; ++i) {
                if (spi_device_flash_payload_buffer_read_word(spi_device, i, &word)) {
                    uprintf(uart, "0x%x\n", word);
                    spi_device_flash_read_buffer_write_word(spi_device, command.address + i, word);
                }
            }
        }
        uart_puts(uart, "\n");

        spi_device_flash_status status = { 0 };
        spi_device_flash_status_set(spi_device, status);
    }

    return true;
}

bool test_main(uart_t console)
{
    spi_device_t spi_device = mocha_system_spi_device();

    spi_device_init(spi_device);

    return spi_cmd_poll_test(spi_device, console);
}
