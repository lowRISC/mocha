/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

INCLUDE memory.ld

MEMORY {
    ram   (RWX) : ORIGIN = ORIGIN(SRAM), LENGTH = (LENGTH(SRAM))
}

_stack_len = 0x1000; /* 4 KiB */

INCLUDE mocha.ld
