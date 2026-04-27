// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha System parameters and Peripheral layout.

#include "hal/mocha.h"
#include <stddef.h>
#include <stdint.h>
#if defined(__riscv_zcherihybrid)
#include <cheriintrin.h>
#endif /* defined(__riscv_zcherihybrid) */

static const uintptr_t rom_base = 0x80000ul;
static const uintptr_t mailbox_base = 0x20010000ul;
static const uintptr_t dv_test_status_base = 0x20020000ul;
static const uintptr_t gpio_base = 0x40000000ul;
static const uintptr_t clkmgr_base = 0x40020000ul;
static const uintptr_t rstmgr_base = 0x40030000ul;
static const uintptr_t pwrmgr_base = 0x40040000ul;
static const uintptr_t rom_ctrl_base = 0x40050000ul;
static const uintptr_t uart_base = 0x41000000ul;
static const uintptr_t i2c_base = 0x42000000ul;
static const uintptr_t spi_device_base = 0x43000000ul;
static const uintptr_t timer_base = 0x44000000ul;
static const uintptr_t spi_host_base = 0x45000000ul;
static const uintptr_t plic_base = 0x48000000ul;

#if defined(__riscv_zcherihybrid)
/* initialised by boot.S */
extern void *_infinite_cap;

static void *get_infinite_capability(void)
{
    return _infinite_cap;
}

/* Create a capability with a given address and length for MMIO access (RW). */
static void *create_mmio_capability(uintptr_t address, size_t length)
{
    void *cap = get_infinite_capability();
    cap = cheri_address_set(cap, address);
    cap = cheri_bounds_set(cap, length);
    cap = cheri_perms_and(cap, CHERI_PERM_READ | CHERI_PERM_WRITE);
    return cap;
}
#endif /* defined(__riscv_zcherihybrid) */

rom_t mocha_system_rom(void)
{
#if defined(__riscv_zcherihybrid)
    return (rom_t)create_mmio_capability(rom_base, 0x8000u);
#else /* !defined(__riscv_zcherihybrid) */
    return (rom_t)rom_base;
#endif /* defined(__riscv_zcherihybrid) */
}

mailbox_t mocha_system_mailbox(void)
{
#if defined(__riscv_zcherihybrid)
    return (mailbox_t)create_mmio_capability(mailbox_base, 0x50u);
#else /* !defined(__riscv_zcherihybrid) */
    return (mailbox_t)mailbox_base;
#endif /* defined(__riscv_zcherihybrid) */
}

gpio_t mocha_system_gpio(void)
{
#if defined(__riscv_zcherihybrid)
    return (gpio_t)create_mmio_capability(gpio_base, 0x48u);
#else /* !defined(__riscv_zcherihybrid) */
    return (gpio_t)gpio_base;
#endif /* defined(__riscv_zcherihybrid) */
}

clkmgr_t mocha_system_clkmgr(void)
{
#if defined(__riscv_zcherihybrid)
    return (clkmgr_t)create_mmio_capability(clkmgr_base, 0x38u);
#else /* !defined(__riscv_zcherihybrid) */
    return (clkmgr_t)clkmgr_base;
#endif /* defined(__riscv_zcherihybrid) */
}

rstmgr_t mocha_system_rstmgr(void)
{
#if defined(__riscv_zcherihybrid)
    return (rstmgr_t)create_mmio_capability(rstmgr_base, 0x48u);
#else /* !defined(__riscv_zcherihybrid) */
    return (rstmgr_t)rstmgr_base;
#endif /* defined(__riscv_zcherihybrid) */
}

pwrmgr_t mocha_system_pwrmgr(void)
{
#if defined(__riscv_zcherihybrid)
    return (pwrmgr_t)create_mmio_capability(pwrmgr_base, 0x80u);
#else /* !defined(__riscv_zcherihybrid) */
    return (pwrmgr_t)pwrmgr_base;
#endif /* defined(__riscv_zcherihybrid) */
}

rom_ctrl_t mocha_system_rom_ctrl(void)
{
#if defined(__riscv_zcherihybrid)
    return (rom_ctrl_t)create_mmio_capability(rom_ctrl_base, 0x48u);
#else /* !defined(__riscv_zcherihybrid) */
    return (rom_ctrl_t)rom_ctrl_base;
#endif /* defined(__riscv_zcherihybrid) */
}

uart_t mocha_system_uart(void)
{
#if defined(__riscv_zcherihybrid)
    return (uart_t)create_mmio_capability(uart_base, sizeof(struct uart_memory_layout));
#else /* !defined(__riscv_zcherihybrid) */
    return (uart_t)uart_base;
#endif /* defined(__riscv_zcherihybrid) */
}

i2c_t mocha_system_i2c(void)
{
#if defined(__riscv_zcherihybrid)
    return (i2c_t)create_mmio_capability(i2c_base, 0x80u);
#else /* !defined(__riscv_zcherihybrid) */
    return (i2c_t)i2c_base;
#endif /* defined(__riscv_zcherihybrid) */
}

spi_device_t mocha_system_spi_device(void)
{
#if defined(__riscv_zcherihybrid)
    return (spi_device_t)create_mmio_capability(spi_device_base, 0x1FC0u);
#else /* !defined(__riscv_zcherihybrid) */
    return (spi_device_t)spi_device_base;
#endif /* defined(__riscv_zcherihybrid) */
}

timer_t mocha_system_timer(void)
{
#if defined(__riscv_zcherihybrid)
    return (timer_t)create_mmio_capability(timer_base, sizeof(struct timer_memory_layout));
#else /* !defined(__riscv_zcherihybrid) */
    return (timer_t)timer_base;
#endif /* defined(__riscv_zcherihybrid) */
}

spi_host_t mocha_system_spi_host(void)
{
#if defined(__riscv_zcherihybrid)
    return (spi_host_t)create_mmio_capability(spi_host_base, 0x38u);
#else /* !defined(__riscv_zcherihybrid) */
    return (spi_host_t)spi_host_base;
#endif /* defined(__riscv_zcherihybrid) */
}

plic_t mocha_system_plic(void)
{
#if defined(__riscv_zcherihybrid)
    return (plic_t)create_mmio_capability(plic_base, sizeof(struct plic_memory_layout));
#else /* !defined(__riscv_zcherihybrid) */
    return (plic_t)plic_base;
#endif /* defined(__riscv_zcherihybrid) */
}

void *mocha_system_dram(void)
{
#if defined(__riscv_zcherihybrid)
    return create_mmio_capability(dram_base, 0x3F800000u);
#else /* !defined(__riscv_zcherihybrid) */
    return (void *)dram_base;
#endif /* defined(__riscv_zcherihybrid) */
}

void *mocha_system_dv_test_status(void)
{
#if defined(__riscv_zcherihybrid)
    return create_mmio_capability(dv_test_status_base, 0x100u);
#else /* !defined(__riscv_zcherihybrid) */
    return (void *)dv_test_status_base;
#endif /* defined(__riscv_zcherihybrid) */
}
