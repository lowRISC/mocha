/* Copyright lowRISC contributors (COSMIC project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

.section .text

.global main
main:
/*Initialize the data section with values from the rom.*/
data_load:
    la t0, _data_init_start
    la t1, _data_init_end
    la t2, _data_start
data_load_loop:
    beq t0, t1, data_load_end
    ld t3, 0(t0)
    sd t3, 0(t2)
    add t0, t0, 8
    add t2, t2, 8
    j data_load_loop
data_load_end:
    jal boot_main
