// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "builtin.h"
#include "constants.h"
#include "hal/gpio.h"
#include "hal/hart.h"
#include "hal/mocha.h"
#include "hal/spi_device.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

#define MAJOR "00"
#define MINOR "01"
#define PATCH "00"

const uintptr_t boot_slots[] = { 0x10008000, 0x80000000 };
struct boot_context {
    uart_t console;
    gpio_t gpio;
    timer_t timer;
};

// These are defined by the linker script.
extern uint8_t _program_start[];
extern uint8_t _program_end[];

// Pointer to devicetree blob, defined in devicetree/mocha.S
extern char dt_blob_start[];

static bool spi_boot_strap(struct boot_context *ctx);
static void page_program(uart_t console, spi_device_t spid, uint32_t offset, uint32_t bytes);
static void boot(uintptr_t addr);
static void led_init(gpio_t gpio);
static void led_animation_run(struct boot_context *ctx);
static bool bootstrap_requested(struct boot_context *ctx);
static bool get_boot_addr(uint32_t *addr);
static void clear_slots();


// TODO: Add support to cheri mode
int main(void)
{
    struct boot_context boot_ctx = (struct boot_context){
        .console = mocha_system_uart(),
        .timer = mocha_system_timer(),
        .gpio = mocha_system_gpio(),
    };

    uart_init(boot_ctx.console);
    uprintf(boot_ctx.console, "\nBoot ROM: v%s.%s.%s\n", MAJOR, MINOR, PATCH);

    timer_init(boot_ctx.timer);
    timer_enable_write(boot_ctx.timer, true);
    if (bootstrap_requested(&boot_ctx)) {
        uprintf(boot_ctx.console, "Entering SPI bootstrap\n");
        clear_slots(); // Cleaning slots from previeous boot.
        // Spin polling the spi_dev and processing incoming data until a reset command is received.
        spi_boot_strap(&boot_ctx);
    }

    uint32_t boot_addr;
    if (!get_boot_addr(&boot_addr)) {
        uprintf(boot_ctx.console, "No valid slot found, default to DRAM\n");
        boot_addr = dram_base;
    }

    uprintf(boot_ctx.console, "\nJumping to: 0x%x\n", boot_addr);
    boot(boot_addr);
    uprintf(boot_ctx.console, "\nFailed to boot?\n");
    return 0;
}

void boot(uintptr_t addr)
{
    /* next boot stages (OpenSBI, Linux, etc..) expect:
     * - hart's hartid stored in the a0 register.
     * - pointer to devicetree blob in the a1 register. */
    unsigned long hartid = hart_hartid_get();
    void (*next_stage)(unsigned long hartid, char *dtb) = (void *)addr;
    next_stage(hartid, dt_blob_start);
}

void clear_slots()
{
    for (size_t i = 0; i < ARRAY_LEN(boot_slots); i++) {
        DEV_WRITE(boot_slots[i], 0x00);
    }
}

bool get_boot_addr(uint32_t *addr)
{
    for (size_t i = 0; i < ARRAY_LEN(boot_slots); i++) {
        uintptr_t slot = boot_slots[i];
        if (DEV_READ(slot) == BOOT_MAGIC_NUMBER) {
            slot += sizeof(uint32_t);
            *addr = DEV_READ(slot);
            return true;
        }
    }
    return false;
}

bool spi_boot_strap(struct boot_context *ctx)
{
    led_init(ctx->gpio);

    spi_device_t spid = mocha_system_spi_device();
    spi_device_init(spid);
    spi_device_enable_set(spid, true);
    spi_device_flash_status_set(spid, 0);

    while (true) {
        led_animation_run(ctx);

        spi_device_cmd_t cmd = spi_device_cmd_get_non_blocking(spid);
        if (cmd.status != spi_device_status_ready) {
            if (cmd.status == spi_device_status_overflow) {
                uprintf(ctx->console, "SPI payload overflow\n");
                spi_device_flash_status_set(spid, 0);
            }
            continue;
        }

        switch (cmd.opcode) {
        case SPI_DEVICE_OPCODE_SECTOR_ERASE4B:
        case SPI_DEVICE_OPCODE_SECTOR_ERASE:
            // No need to erase SRAM.
            break;
        case SPI_DEVICE_OPCODE_PAGE_PROGRAM4B:
        case SPI_DEVICE_OPCODE_PAGE_PROGRAM:
            if (cmd.payload_byte_count > 0) {
                page_program(ctx->console, spid, cmd.address, cmd.payload_byte_count);
            }
            break;
        case SPI_DEVICE_OPCODE_RESET:
            // Exit boot strap
            return true;
        default:
            uprintf(ctx->console, "\nUnsupported command: 0x%0x", cmd.opcode);
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
    uintptr_t ptr = offset;
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

enum { num_leds = 8, led_animation_period_us = 1 * 1000 * 1000 };

void led_init(gpio_t gpio)
{
    for (size_t led = 0; led < num_leds; led++) {
        gpio_set_oe_pin(gpio, led, true);
    }
}

void led_animation_run(struct boot_context *ctx)
{
    static int current_led = 0;
    static bool going_up = false;
    static uint64_t timeout = 0;

    uint64_t now = timer_value_read_us(ctx->timer);
    if (timeout > now) {
        return;
    }
    timeout = (led_animation_period_us / num_leds) + now;

    gpio_write_pin(ctx->gpio, current_led, going_up);

    int next_led = current_led + (going_up ? 1 : -1);
    bool toggle = (next_led >= num_leds || next_led < 0);
    current_led = toggle ? current_led : next_led;
    going_up ^= toggle;
}

bool bootstrap_requested(struct boot_context *ctx)
{
    enum { bootstrap_pin = 8, debounce_us = 20 * 1000 };
    timer_schedule_in_us(ctx->timer, debounce_us);
    if (!gpio_read_pin(ctx->gpio, bootstrap_pin)) {
        while (!timer_interrupt_pending(ctx->timer)) {
            if (gpio_read_pin(ctx->gpio, bootstrap_pin)) {
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
