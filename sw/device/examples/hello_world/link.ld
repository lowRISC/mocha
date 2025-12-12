// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

OUTPUT_ARCH(riscv)

MEMORY
{
    ram         : ORIGIN = 0x00100000, LENGTH = 0x1F000 /* 124 KiB */
    stack       : ORIGIN = 0x0011F000, LENGTH = 0x01000 /* 4 KiB */
}

/* Stack information variables */
_min_stack      = 0x1000;   /* 4K - minimum stack space to reserve */
_stack_len     = LENGTH(stack);
_stack_start   = ORIGIN(stack) + LENGTH(stack);

_entry_point = _vectors_start + 0x80;
ENTRY(_entry_point)

/* Rust dependency */
PROVIDE(_stext = ORIGIN(ram));
PROVIDE(_stack_start = ORIGIN(stack) + LENGTH(stack));
PROVIDE(_max_hart_id = 0);
PROVIDE(_hart_stack_size = LENGTH(stack));
PROVIDE(_heap_size = 0);
PROVIDE(UserSoft = DefaultHandler);
PROVIDE(SupervisorSoft = DefaultHandler);
PROVIDE(MachineSoft = DefaultHandler);
PROVIDE(UserTimer = DefaultHandler);
PROVIDE(SupervisorTimer = DefaultHandler);
PROVIDE(MachineTimer = DefaultHandler);
PROVIDE(UserExternal = DefaultHandler);
PROVIDE(SupervisorExternal = DefaultHandler);
PROVIDE(MachineExternal = DefaultHandler);
PROVIDE(DefaultHandler = DefaultInterruptHandler);
PROVIDE(ExceptionHandler = DefaultExceptionHandler);
PROVIDE(__pre_init = default_pre_init);
PROVIDE(_mp_hook = default_mp_hook);
PROVIDE(_start_trap = default_start_trap);
PROVIDE(_setup_interrupts = default_setup_interrupts);

SECTIONS
{
    .text : {
        . = ALIGN(8);
        _vectors_start = .;
        KEEP(*(.vectors))
        _vectors_end = .;
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
