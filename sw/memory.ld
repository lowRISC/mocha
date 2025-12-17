/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

MEMORY
{
    ram         : ORIGIN = 0x10000000, LENGTH = 0x1F000 /* 124 KiB */
    stack       : ORIGIN = 0x1001F000, LENGTH = 0x01000 /* 4 KiB */
}
