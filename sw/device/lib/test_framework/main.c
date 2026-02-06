// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include "runtime/string.h"
#include <stdbool.h>
#include <stdint.h>

enum test_status {
    TEST_STATUS_IN_TEST = 0x4354u,
    TEST_STATUS_PASSED = 0x900du,
    TEST_STATUS_FAILED = 0xbaadu,
};

/* magic byte string to terminate the verilator simulation */
static const char magic[] = "\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7";

/* the test's main function. returns whether the test was successful or not */
[[gnu::weak]] bool test_main(uart_t console)
{
    (void)console;
    /* fail by default */
    return false;
}

/* the test's interrupt handler. returns whether the interrupt was handled successfully.
 * the test is aborted if this function returns false. */
[[gnu::weak]] bool test_interrupt_handler(size_t irq)
{
    (void)irq;
    /* by default, all interrupts are unhandled */
    return false;
}

/* the test's exception handler. returns whether the exception was handled successfully.
 * the test is aborted if this function returns false. */
[[gnu::weak]] bool
test_exception_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
    /* by default, all exceptions are unhandled */
    return false;
}

void system_reset()
{
    /* 
     * We don't have a hardware system reset yet. So we workaround by jumping back to the bootROM.
     */
    enum { bootROM = 0x10000080 };
    typedef void (*reset_handler_t)(void);
    reset_handler_t reset = (reset_handler_t)bootROM;
#if defined(__riscv_zcherihybrid)
    // Disable cheri because in a normal system reset cheri is disabled by default.
    __asm__ volatile("modesw.int");
#endif
    reset();
}

/* exit the test with a pass or fail */
[[noreturn]] void test_exit(bool success)
{
    uart_t console = mocha_system_uart();
    void *dv_test_status = mocha_system_dv_test_status();

    uart_puts(console, "TEST RESULT: ");
    uart_puts(console, success ? "PASSED" : "FAILED");
    DEV_WRITE(dv_test_status, success ? TEST_STATUS_PASSED : TEST_STATUS_FAILED);

    uart_putchar(console, '\n');
    uart_puts(console, "Safe to exit simulator.");
    uart_puts(console, magic);

    /* 
     * Magic string should have terminated the verilator simulation.
     * If we got here, we might be running on the FPGA, so we need to go back to the bootROM for a
     * new test to be loaded.
     */
    uprintf(console, "Jumping back to loader.");
    system_reset();
    while (true) {
    }
}

[[noreturn]] void main(void)
{
    uart_t console = mocha_system_uart();
    void *dv_test_status = mocha_system_dv_test_status();

    uart_init(console);
    DEV_WRITE(dv_test_status, TEST_STATUS_IN_TEST);

    bool result = test_main(console);

    test_exit(result);
}

static const size_t register_name_max = 5;

static const char *register_abi_name[32] = {
/* clang-format off */
#if defined(__riscv_zcherihybrid)
    "cnull", "cra", "csp",  "cgp",
    "ctp",   "ct0", "ct1",  "ct2",
    "cs0",   "cs1", "ca0",  "ca1",
    "ca2",   "ca3", "ca4",  "ca5",
    "ca6",   "ca7", "cs2",  "cs3",
    "cs4",   "cs5", "cs6",  "cs7",
    "cs8",   "cs9", "cs10", "cs11",
    "ct3",   "ct4", "ct5",  "ct6",
#else /* !defined(__riscv_zcherihybrid) */
    "zero", "ra", "sp",  "gp",
    "tp",   "t0", "t1",  "t2",
    "s0",   "s1", "a0",  "a1",
    "a2",   "a3", "a4",  "a5",
    "a6",   "a7", "s2",  "s3",
    "s4",   "s5", "s6",  "s7",
    "s8",   "s9", "s10", "s11",
    "t3",   "t4", "t5",  "t6",
#endif /* defined(__riscv_zcherihybrid) */
    /* clang-format on */
};

void print_register_trace(struct trap_registers *registers, struct trap_context *context)
{
    uart_t console = mocha_system_uart();
#if defined(__riscv_zcherihybrid)
    uprintf(console, "epcc:  %#p\n", &context->epc);
#else /* !defined(__riscv_zcherihybrid) */
    uprintf(console, "epc:   %lx\n", (unsigned long)context->epc);
#endif /* defined(__riscv_zcherihybrid) */
    uprintf(console, "cause: %lx\n", context->cause);
    uprintf(console, "tval:  %lx\n", context->tval);
    uprintf(console, "tval2: %lx\n", context->tval2);
    for (size_t i = 0; i < 32; i++) {
        size_t reg_name_len = strlen(register_abi_name[i]);
        uprintf(console, "%s: ", register_abi_name[i]);
        /* pad with spaces for alignment */
        while (reg_name_len++ < register_name_max) {
            uart_putchar(console, ' ');
        }
#if defined(__riscv_zcherihybrid)
        uprintf(console, "%#p\n", &registers->x[i]);
#else /* !defined(__riscv_zcherihybrid) */
        uprintf(console, "%lx\n", (unsigned long)registers->x[i]);
#endif /* defined(__riscv_zcherihybrid) */
    }
}

/* internal interrupt handler, calls the test-defined test_interrupt_handler to handle
 * the interrupt. if the handler does not succeed, the test is aborted */
void _interrupt_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    /* call the test's provided interrupt handler */
    bool handled = test_interrupt_handler(context->cause);
    if (!handled) {
        uart_t console = mocha_system_uart();
        uart_puts(console, "unhandled interrupt!\n");
        print_register_trace(registers, context);
        test_exit(false);
    }
}

/* whether we are already in an exception handler or not */
static bool in_exception = false;

/* internal exception handler, calls the test-defined test_exception_handler to handle.
 * the exception. if the handler does not succeed, the test is aborted */
void _exception_handler(struct trap_registers *registers, struct trap_context *context)
{
    /* fail if we get an exception in the exception handler */
    if (in_exception) {
        uart_t console = mocha_system_uart();
        uart_puts(console, "exception in exception handler!\n");
        print_register_trace(registers, context);
        test_exit(false);
    }
    in_exception = true;
    /* call the test's provided exception handler */
    bool handled = test_exception_handler(registers, context);
    if (!handled) {
        uart_t console = mocha_system_uart();
        uart_puts(console, "unhandled exception!\n");
        print_register_trace(registers, context);
        test_exit(false);
    }
    in_exception = false;
}

/* internal trap handler, called from trap_vector.S.
 * dispatches to the internal interrupt or exception handler appropriately */
void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    if (context->cause & (1ul << 63)) {
        /* trap cause is interrupt */
        /* clear interrupt bit as it is implied by interrupt handler function */
        context->cause &= ~(1ul << 63);
        _interrupt_handler(registers, context);
    } else {
        /* trap cause is exception */
        _exception_handler(registers, context);
    }
}
