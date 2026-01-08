/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

MEMORY {
    ram   (RWX) : ORIGIN = 0x10000000, LENGTH = 0x1F000 /* 124 KiB */
    stack (ARW) : ORIGIN = 0x1001F000, LENGTH = 0x01000 /* 4 KiB */
}

/* Stack */
_stack_len = LENGTH(stack);
_stack_top = ORIGIN(stack) + LENGTH(stack);

/* Provided in init_vectors.S, immediately jumps into _start. */
ENTRY(_init_vector)

SECTIONS {
    .init_vectors ORIGIN(ram) : {
        *(.init_vectors)
    } > ram

    .text : {
        . = ALIGN(8);
        *(.text)
        *(.text.*)
        . = ALIGN(8);
    } > ram

    .rodata : {
        . = ALIGN(8);
        /* Small rodata before large rodata */
        *(.srodata)
        *(.srodata.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(8);
    } > ram

    /* capability relocation entries */
    /* __start___cap_relocs and __stop___cap_relocs are provided by the toolchain */
    __cap_relocs : {
        *(__cap_relocs)
        . = ALIGN(8);
    } > ram

    .data : {
        . = ALIGN(8);
        /* Small data before large data */
        *(.sdata)
        *(.sdata.*)
        *(.data)
        *(.data.*)
        . = ALIGN(8);
    } > ram

    .bss : {
        . = ALIGN(8);
        _bss_start = .;
        _sbss = .; /* Rust */
        /* Small bss before large bss */
        *(.sbss)
        *(.sbss.*)
        *(.bss)
        *(.bss.*)
        *(COMMON)
        _bss_end = .;
        _ebss = .; /* Rust */
        . = ALIGN(8);
    } > ram

    .got : {
        . = ALIGN(8);
        *(.got)
        *(.got.*)
        . = ALIGN(8);
    } > ram
}
