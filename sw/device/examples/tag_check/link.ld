/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

MEMORY
{
    ram         : ORIGIN = 0x10000000, LENGTH = 0x1F000 /* 124 KiB */
    stack       : ORIGIN = 0x1001F000, LENGTH = 0x01000 /* 4 KiB */
}

/* Stack information variables */
_min_stack      = 0x1000;   /* 4K - minimum stack space to reserve */
_stack_len     = LENGTH(stack);
_stack_start   = ORIGIN(stack) + LENGTH(stack);


SECTIONS
{
    .text : {
        . = . + 0x80;
        *(.text)
        *(.text.*)
        . = ALIGN(8);
    }  > ram

    .rodata : {
        . = ALIGN(8);
        /* Small RO data before large RO data */
        *(.srodata)
        *(.srodata.*)
        *(.rodata);
        *(.rodata.*)
        . = ALIGN(8);
    } > ram

    .data : {
        . = ALIGN(8);
        /* Small data before large data */
        *(.sdata)
        *(.sdata.*)
        *(.data);
        *(.data.*)
        . = ALIGN(8);
    } > ram

    .bss :
    {
        . = ALIGN(8);
        _bss_start = .;
        /* Small BSS before large BSS */
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
        . = ALIGN(8);
    } > ram
    /* Rust dependency */
    _sbss = _bss_start;
    _ebss = _bss_end;

    /* ensure there is enough room for stack */
    .stack (NOLOAD): {
        . = ALIGN(8);
        . = . + _min_stack ;
        . = ALIGN(8);
        stack = . ;
        _stack = . ;
    } > stack
}
