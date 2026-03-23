// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "builtin.h"
#include "hal/uart.h"
#include <stdbool.h>

/* this test attempts to execute two unimplemented instructions and skip over
 * them in the exception handler, to test the exception handling implementation */
bool test_main(uart_t console)
{
    asm volatile(".option push\n"
                 ".option arch,-c\n"
                 "unimp\n"
                 ".option pop\n");

    uart_puts(console, "skipped over 4-byte unimp!\n");

    asm volatile(".option push\n"
                 ".option arch,+c\n"
                 "unimp\n"
                 ".option pop\n");

    uart_puts(console, "skipped over 2-byte unimp!\n");

    return true;
}

bool test_exception_handler(struct trap_registers *regs, struct trap_context *context)
{
    (void)regs;
    if (context->cause == 2) {
        /* illegal instruction exception */
        if (context->tval == 0x00000000ul) {
            /* skip over the 2-byte unimp instruction */
            context->epc += 2;
            return true;
        }
        if (context->tval == 0xc0001073ul) {
            /* skip over the 4-byte unimp instruction */
            context->epc += 4;
            return true;
        }
    }
    /* all other exception types are unexpected */
    return false;
}
