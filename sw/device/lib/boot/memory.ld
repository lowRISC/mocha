/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */
/* Auto-generated: 'util/rdlgenerator.py gen-linker-script build/rdl/rdl.json sw/device/lib/boot/memory.ld' */

MEMORY {
    ROM       : ORIGIN = 0x00080000, LENGTH = 0x00020000 /* 128.0 kiB */
    SRAM      : ORIGIN = 0x10000000, LENGTH = 0x00020000 /* 128.0 kiB */
    DRAM      : ORIGIN = 0x80000000, LENGTH = 0x80000000 /* 2.0 GiB */
}
