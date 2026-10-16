// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mocha System parameters and Peripheral layout.

#include "hal/mocha.h"
#include <stddef.h>
#include <stdint.h>
#if defined(__riscv_zyhybrid)
#include <cheriintrin.h>
#endif /* defined(__riscv_zyhybrid) */

static const uintptr_t rom_base = 0x80000ul;
static const uintptr_t mailbox_base = 0x20010000ul;
static const uintptr_t dv_window_base = 0x20020000ul;
static const uintptr_t ethernet_base = 0x30000000ul;
static const uintptr_t gpio_base = 0x40000000ul;
static const uintptr_t clkmgr_base = 0x40020000ul;
static const uintptr_t rstmgr_base = 0x40030000ul;
static const uintptr_t pwrmgr_base = 0x40040000ul;
static const uintptr_t rom_ctrl_base = 0x40050000ul;
static const uintptr_t entropy_src_base = 0x40060000ul;
static const uintptr_t uart_base = 0x41000000ul;
static const uintptr_t i2c_base = 0x42000000ul;
static const uintptr_t spi_device_base = 0x43000000ul;
static const uintptr_t timer_base = 0x44000000ul;
static const uintptr_t spi_host_base = 0x45000000ul;
static const uintptr_t plic_base = 0x48000000ul;

#if defined(__riscv_zyhybrid)
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
#endif /* defined(__riscv_zyhybrid) */

rom_t mocha_system_rom(void)
{
#if defined(__riscv_zyhybrid)
    return (rom_t)create_mmio_capability(rom_base, 0x8000u);
#else /* !defined(__riscv_zyhybrid) */
    return (rom_t)rom_base;
#endif /* defined(__riscv_zyhybrid) */
}

mailbox_t mocha_system_mailbox(void)
{
#if defined(__riscv_zyhybrid)
    return (mailbox_t)create_mmio_capability(mailbox_base, 0x50u);
#else /* !defined(__riscv_zyhybrid) */
    return (mailbox_t)mailbox_base;
#endif /* defined(__riscv_zyhybrid) */
}

ethernet_t mocha_system_ethernet(void)
{
#if defined(__riscv_zyhybrid)
    return (ethernet_t)create_mmio_capability(ethernet_base, 0x8000u);
#else /* !defined(__riscv_zyhybrid) */
    return (ethernet_t)ethernet_base;
#endif /* defined(__riscv_zyhybrid) */
}

gpio_t mocha_system_gpio(void)
{
#if defined(__riscv_zyhybrid)
    return (gpio_t)create_mmio_capability(gpio_base, 0x48u);
#else /* !defined(__riscv_zyhybrid) */
    return (gpio_t)gpio_base;
#endif /* defined(__riscv_zyhybrid) */
}

clkmgr_t mocha_system_clkmgr(void)
{
#if defined(__riscv_zyhybrid)
    return (clkmgr_t)create_mmio_capability(clkmgr_base, sizeof(struct clkmgr_memory_layout));
#else /* !defined(__riscv_zyhybrid) */
    return (clkmgr_t)clkmgr_base;
#endif /* defined(__riscv_zyhybrid) */
}

rstmgr_t mocha_system_rstmgr(void)
{
#if defined(__riscv_zyhybrid)
    return (rstmgr_t)create_mmio_capability(rstmgr_base, 0x48u);
#else /* !defined(__riscv_zyhybrid) */
    return (rstmgr_t)rstmgr_base;
#endif /* defined(__riscv_zyhybrid) */
}

pwrmgr_t mocha_system_pwrmgr(void)
{
#if defined(__riscv_zyhybrid)
    return (pwrmgr_t)create_mmio_capability(pwrmgr_base, 0x44u);
#else /* !defined(__riscv_zyhybrid) */
    return (pwrmgr_t)pwrmgr_base;
#endif /* defined(__riscv_zyhybrid) */
}

rom_ctrl_t mocha_system_rom_ctrl(void)
{
#if defined(__riscv_zyhybrid)
    return (rom_ctrl_t)create_mmio_capability(rom_ctrl_base, 0x48u);
#else /* !defined(__riscv_zyhybrid) */
    return (rom_ctrl_t)rom_ctrl_base;
#endif /* defined(__riscv_zyhybrid) */
}

entropy_src_t mocha_system_entropy_src(void)
{
#if defined(__riscv_zyhybrid)
    return (entropy_src_t)create_mmio_capability(entropy_src_base,
                                                 sizeof(struct entropy_src_memory_layout));
#else /* !defined(__riscv_zyhybrid) */
    return (entropy_src_t)entropy_src_base;
#endif /* defined(__riscv_zyhybrid) */
}

uart_t mocha_system_uart(void)
{
#if defined(__riscv_zyhybrid)
    return (uart_t)create_mmio_capability(uart_base, sizeof(struct uart_memory_layout));
#else /* !defined(__riscv_zyhybrid) */
    return (uart_t)uart_base;
#endif /* defined(__riscv_zyhybrid) */
}

i2c_t mocha_system_i2c(void)
{
#if defined(__riscv_zyhybrid)
    return (i2c_t)create_mmio_capability(i2c_base, 0x80u);
#else /* !defined(__riscv_zyhybrid) */
    return (i2c_t)i2c_base;
#endif /* defined(__riscv_zyhybrid) */
}

spi_device_t mocha_system_spi_device(void)
{
#if defined(__riscv_zyhybrid)
    return (spi_device_t)create_mmio_capability(spi_device_base, 0x1FC0u);
#else /* !defined(__riscv_zyhybrid) */
    return (spi_device_t)spi_device_base;
#endif /* defined(__riscv_zyhybrid) */
}

timer_t mocha_system_timer(void)
{
#if defined(__riscv_zyhybrid)
    return (timer_t)create_mmio_capability(timer_base, sizeof(struct timer_memory_layout));
#else /* !defined(__riscv_zyhybrid) */
    return (timer_t)timer_base;
#endif /* defined(__riscv_zyhybrid) */
}

spi_host_t mocha_system_spi_host(void)
{
#if defined(__riscv_zyhybrid)
    return (spi_host_t)create_mmio_capability(spi_host_base, 0x38u);
#else /* !defined(__riscv_zyhybrid) */
    return (spi_host_t)spi_host_base;
#endif /* defined(__riscv_zyhybrid) */
}

plic_t mocha_system_plic(void)
{
#if defined(__riscv_zyhybrid)
    return (plic_t)create_mmio_capability(plic_base, sizeof(struct plic_memory_layout));
#else /* !defined(__riscv_zyhybrid) */
    return (plic_t)plic_base;
#endif /* defined(__riscv_zyhybrid) */
}

void *mocha_system_dram(void)
{
#if defined(__riscv_zyhybrid)
    return create_mmio_capability(dram_base, 0x3F800000u);
#else /* !defined(__riscv_zyhybrid) */
    return (void *)dram_base;
#endif /* defined(__riscv_zyhybrid) */
}

dv_window_t mocha_system_dv_window(void)
{
#if defined(__riscv_zyhybrid)
    return (
        dv_window_t)create_mmio_capability(dv_window_base, sizeof(struct dv_window_memory_layout));
#else /* !defined(__riscv_zyhybrid) */
    return (dv_window_t)dv_window_base;
#endif /* defined(__riscv_zyhybrid) */
}
