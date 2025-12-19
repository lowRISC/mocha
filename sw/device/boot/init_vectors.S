// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

.section .init_vectors, "ax"
.option push
.option norvc
.zero 128
    /* On the CVA-6, RAM+0x80 is the reset vector */
    j _start
.zero 60
    /* On the CVA-6, RAM+0xC0 is the reset value of mtvec */
    /* By default, just spin in place on exception */
_init_exception_handler:
    j _init_exception_handler
.option pop
