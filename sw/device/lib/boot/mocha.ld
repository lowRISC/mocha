/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

INCLUDE memory.ld

_stack_len = 0x1000; /* 4 KiB */

/* TODO: Remove this when we implement a ROM. */
/* This should be provided by the build system, otherwise the default is 0x0000*/
PROVIDE(BOOT_ROM_OFFSET=0x0000);
_offset_ = BOOT_ROM_OFFSET; 

MEMORY {
    ram   (RWX) : ORIGIN = ORIGIN(SRAM) + _offset_, LENGTH = (LENGTH(SRAM) - _stack_len - _offset_)
    stack (ARW) : ORIGIN = ORIGIN(ram) + LENGTH(ram), LENGTH = _stack_len 
}

/* Stack */
_stack_bottom = ORIGIN(stack);
_stack_top = _stack_bottom + _stack_len;

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
    _program_end = .;
}
