// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/gpio.h"
#include "hal/mocha.h"
#include "hal/spi_device.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

// These are defined by the linker script.
extern uint8_t _program_start[];
extern uint8_t _program_end[];

static bool spi_boot_strap(uart_t console);
static void page_program(uart_t console, spi_device_t spid, uint32_t offset, uint32_t bytes);
static void boot(uintptr_t addr);
static void led_init(gpio_t gpio);
static void led_animation_run(gpio_t gpio);
static bool bootstrap_requested(gpio_t gpio, timer_t timer);


// TODO: Add support to cheri mode
int main(void)
{
    uart_t console = mocha_system_uart();
    uart_init(console);
    uprintf(console, "\nBoot ROM!\n");

    timer_t timer = mocha_system_timer();
    timer_init(timer);
    timer_enable_write(timer, true);

    gpio_t gpio = mocha_system_gpio();
    if (bootstrap_requested(gpio, timer)) {
        uprintf(console, "Entering spi bootstrap\n");
        // Spin polling the spi_dev and processing incoming data until a reset command is received.
        spi_boot_strap(console);
    }

    enum { BootAddress = 0x10004080 };
    uprintf(console, "\nJumping to: 0x%x\n", BootAddress);

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
    gpio_t gpio = mocha_system_gpio();
    led_init(gpio);

    spi_device_t spid = mocha_system_spi_device();
    spi_device_init(spid);
    spi_device_enable_set(spid, true);
    spi_device_flash_status_set(spid, 0);

    uint32_t received_resets = 0;
    size_t count = 0;

    while (true) {
        // TODO: Use timer
        if (count++ >= 20000) {
            led_animation_run(gpio);
            count = 0;
        }

        spi_device_cmd_t cmd = spi_device_cmd_get_non_blocking(spid);
        if (cmd.status != spi_device_status_ready) {
            if (cmd.status == spi_device_status_overflow) {
                uprintf(console, "SPI payload overflow\n");
                spi_device_flash_status_set(spid, 0);
            }
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
            // This is a workaround to openFPGALoader that starts with a reset.
            if (received_resets++ > 0) {
                // Exit boot strap
                spi_device_enable_set(spid, false);
                return true;
            }
            uprintf(console, "\nFirst reset");
            break;
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

enum { num_leds = 8 };

void led_init(gpio_t gpio)
{
    for (size_t led = 0; led < num_leds; led++) {
        gpio_set_oe_pin(gpio, led, true);
    }
}

void led_animation_run(gpio_t gpio)
{
    static int current_led = 0;
    static bool going_up = false;

    gpio_write_pin(gpio, current_led, going_up);

    int next_led = current_led + (going_up ? 1 : -1);
    bool toggle = (next_led >= num_leds || next_led < 0);
    current_led = toggle ? current_led : next_led;
    going_up ^= toggle;
}

bool bootstrap_requested(gpio_t gpio, timer_t timer)
{
    enum { bootstrap_pin = 8, debaunce_us = 20000 };
    timer_schedule_in_us(timer, debaunce_us);
    if (!gpio_read_pin(gpio, bootstrap_pin)) {
        while (!timer_interrupt_pending(timer)) {
            if (gpio_read_pin(gpio, bootstrap_pin)) {
                return false;
            }
        }
        return true;
    }
    return false;
}

// TODO: Catch exceptions properly.
void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
