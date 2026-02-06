// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "hal/spi_device.h"
#include "hal/uart.h"
#include <stdbool.h>
#include <stdint.h>

// These are defined by the linker script.
extern uint8_t _program_start[];
extern uint8_t _program_end[];

static bool spi_boot_strap(uart_t console);
static void page_program(uart_t console, spi_device_t spid, uint32_t offset, uint32_t bytes);
static void boot(uintptr_t addr);

// TODO: Add support to cheri mode
int main(void)
{
    uart_t console = mocha_system_uart();
    uart_init(console);
    uprintf(console, "\nBoot ROM!\n");

    // Spin polling the spi_dev and processng incoming data until a reset command is received.
    spi_boot_strap(console);

    enum { BootAddress = 0x10004080 };
    uprintf(console, "\nJumping to: 0x%0x\n", BootAddress);

    boot(BootAddress);
    uprintf(console, "\nFailed to boot?\n");
    return 0;
}

void boot(uintptr_t addr)
{
    typedef void (*reset_handler_t)(void);
    reset_handler_t reset = (reset_handler_t)addr;
    reset();
}

bool spi_boot_strap(uart_t console)
{
    spi_device_t spid = mocha_system_spi_device();
    spi_device_init(spid);
    spi_device_flash_status_set(spid, 0);

    while (true) {
        spi_device_cmd_t cmd = spi_device_cmd_get(spid);
        if (cmd.status != 0) {
            uprintf(console, "SPI payload overflow\n");
            spi_device_flash_status_set(spid, 0);
            continue;
        }

        switch (cmd.opcode) {
        case SPI_DEVICE_OPCODE_SECTOR_ERASE:
            // No need to erase SRAM.
            break;
        case SPI_DEVICE_OPCODE_PAGE_PROGRAM:
            if (cmd.payload_byte_count > 0) {
                page_program(console, spid, cmd.address, cmd.payload_byte_count);
            }
            break;
        case SPI_DEVICE_OPCODE_RESET:
            // Exit boot strap
            return true;
        default:
            uprintf(console, "\nUnsupported command: 0x%0x", cmd.opcode);
            break;
        }
        // Finished processing the write, clear the busy bit.
        spi_device_flash_status_set(spid, 0);
    }

    return true;
}

static inline bool is_overriding_me(uintptr_t addr)
{
    return addr >= (uintptr_t)_program_start && addr < (uintptr_t)_program_end;
}

void page_program(uart_t console, spi_device_t spid, uint32_t offset, uint32_t bytes)
{
    // TODO: Enable the spi flash 4 bytes addressing.
    enum { SramOffset = 0x10000000 };
    uintptr_t ptr = SramOffset + offset;
    uint32_t payload_offset = 0;

    if (bytes > SPI_DEVICE_PAYLOAD_AREA_NUM_BYTES) {
        uprintf(console, "\npage program size out of bounds");
        return;
    }

    // TODO: Now only SRAM is supported, but when 4 bytes addressing is enabled and the HW supports
    // DRAM and ROM, then we need to check that the offset is valid within a memory address space.
    if (is_overriding_me(ptr) || is_overriding_me(ptr + bytes)) {
        uprintf(console, "\nPlease don't override the bootROM.");
        return;
    }

    while (payload_offset < bytes) {
        *((volatile uint64_t *)ptr) = spi_device_flash_payload_buffer_read64(spid, payload_offset);
        ptr += sizeof(uint64_t);
        payload_offset += sizeof(uint64_t);
    }
}

// TODO: Catch exceptions properly.
void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
