/* Copyright lowRISC contributors. */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/* A simple test payload to use with OpenSBI. */
/* This performs an SBI call to print the success string and */
/* writes to the DV Test Status register to indicate success. */

#define SBI_DEBUG_CONSOLE       0x4442434e
#define SBI_DEBUG_CONSOLE_WRITE 0

#define DV_TEST_STATUS        0x20020000
#define DV_TEST_STATUS_PASSED 0x900d

.section .text

.globl _start
_start:
    /* Perform an SBI call to print test_status_string. */
    li  a7, SBI_DEBUG_CONSOLE
    li  a6, SBI_DEBUG_CONSOLE_WRITE
    li  a0, 20
    lla a1, test_status_string
    li  a2, 0
    li  a3, 0
    li  a4, 0
    li  a5, 0
    ecall

    /* Write to DV Test Status */
    lla a0, DV_TEST_STATUS
    li  a1, DV_TEST_STATUS_PASSED
    sw  a1, 0(a0)

loop:
    wfi
    j loop

.section .data

test_status_string:
    .string "TEST RESULT: PASSED\n"
    .align 3
