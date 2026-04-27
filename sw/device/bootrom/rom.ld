/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

OUTPUT_ARCH(riscv)

INCLUDE memory.ld

/* Place the rom data at the end of the SRAM to make space at the beggining for programs to be
 * loaded at the begginning of the SRAM.*/  
__offset_ = LENGTH(SRAM) * 3 / 4;

MEMORY {
    rom   (RX) : ORIGIN = ORIGIN(ROM)             , LENGTH = LENGTH(ROM)
    ram   (RW) : ORIGIN = ORIGIN(SRAM) + __offset_, LENGTH = (LENGTH(SRAM) - __offset_)
}

_stack_len = 0x1000; /* 4 KiB */

/* Provided in init_vectors.S, immediately jumps into _start. */
ENTRY(_init_vector)

SECTIONS {
    .init_vectors ORIGIN(rom) : {
        *(.init_vectors)
    } > rom

    .text : {
        . = ALIGN(8);
        *(.text)
        *(.text.*)
        . = ALIGN(8);
    } > rom

    .rodata : {
        . = ALIGN(8);
        /* Small rodata before large rodata */
        *(.srodata)
        *(.srodata.*)
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(8);
    } > rom

    .got : {
        . = ALIGN(8);
        *(.got)
        *(.got.*)
        . = ALIGN(8);
    } > rom

    .data : {
        . = ALIGN(8);

        _ram_start = .;
        _data_start = .;
        _data_init_start = LOADADDR(.data);

        /* Small data before large data */
        *(.sdata)
        *(.sdata.*)
        *(.data)
        *(.data.*)
        . = ALIGN(8);

        _data_end = .;
        _data_init_end = LOADADDR(.data) + SIZEOF(.data);

    } > ram AT > rom  /* VMA = ram, LMA = rom */

    .bss (NOLOAD):  {
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

    .stack (NOLOAD):  {
        . = ALIGN(64);
        _stack_bottom = .;
        . = . + _stack_len;
        _stack_top = .;
        _ram_end = .;
    } > ram
    . = ALIGN(8);
}
