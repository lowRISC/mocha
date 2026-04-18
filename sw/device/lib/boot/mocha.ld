/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */


/* Provided in init_vectors.S, immediately jumps into _start. */
ENTRY(_init_vector)

SECTIONS {
    _program_start = ORIGIN(ram);

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
        . = ALIGN(8);
        _ebss = .; /* Rust */
        _bss_end = .;
    } > ram

    .got : {
        . = ALIGN(8);
        *(.got)
        *(.got.*)
        . = ALIGN(8);
    } > ram

    . = ALIGN(1024);
    .stack : {
        . = ALIGN(1024);
        _stack_bottom = .;
        . = . + _stack_len;
        _stack_top = .;
    } > ram

    . = ALIGN(8);
    _program_end = .;
}
