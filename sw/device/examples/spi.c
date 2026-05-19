// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/spi_device.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdint.h>

int main(void)
{
    uart_t uart = mocha_system_uart();
    spi_device_t spi_device = mocha_system_spi_device();
    uart_init(uart);
    spi_device_init(spi_device);
    spi_device_flash_mode_set(spi_device, spi_device_flash_mode_flash);
    const spi_device_flash_status clear_status = { 0 };
    spi_device_flash_status_set(spi_device, clear_status);

    uprintf(uart, "Hello SPI in Mocha!\n");

    // Poll and process SPI command
    spi_device_software_command cmd;
    while (true) {
        // Now process SPI command (if any)
        enum spi_device_status status = spi_device_software_command_get(spi_device, &cmd);
        if (status != spi_device_status_ready) {
            if (status == spi_device_status_overflow) {
                uprintf(uart, "SPI payload overflow\n");
                spi_device_flash_status_set(spi_device, clear_status);
                continue;
            }
        }

        switch (cmd.opcode) {
        case spi_device_opcode_chip_erase:
            uprintf(uart, "SPI CHIP ERASE");
            break;
        case spi_device_opcode_sector_erase:
            uprintf(uart, "SPI SECTOR ERASE");
            break;
        case spi_device_opcode_page_program:
            uprintf(uart, "SPI PAGE PROGRAM");
            break;
        case spi_device_opcode_reset:
            uprintf(uart, "SPI RESET");
            break;
        default:
            uprintf(uart, "SPI ??");
            break;
        }

        if (cmd.has_address) {
            uprintf(uart, " addr: 0x%x\n", cmd.address);
        }

        if (cmd.payload_byte_count > 0) {
            uprintf(uart, "payload bytes: 0x%x\n", cmd.payload_byte_count);
            uint32_t payload_word_count = ((uint32_t)cmd.payload_byte_count) / sizeof(uint32_t);
            if ((cmd.payload_byte_count % sizeof(uint32_t)) != 0) {
                payload_word_count++;
            }

            uprintf(uart, "payload data:\n");

            uint32_t word;
            for (uint32_t i = 0; i < payload_word_count; ++i) {
                if (spi_device_flash_payload_buffer_read_word(spi_device, i, &word)) {
                    uprintf(uart, "0x%x\n", word);
                }
            }
        }

        uprintf(uart, "\n");

        spi_device_flash_status_set(spi_device, clear_status);
    }

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
