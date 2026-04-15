/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

#include "constants.h"

.section .init_vectors, "ax"
.option push
.option norvc
/*Magic word checked by the bootrom*/
.word BOOT_MAGIC_NUMBER
/*Used by the bootrom to jump to the _start*/
.word _init_vector
.zero 120
    /* On the CVA-6, RAM+0x80 is the reset vector */
.global _init_vector
_init_vector:
    j _start
.zero 60
    /* On the CVA-6, RAM+0xC0 is the reset value of mtvec */
    /* By default, just spin in place on exception */
_init_exception_handler:
    j _init_exception_handler
.option pop
