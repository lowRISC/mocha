# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

.macro expect_tag_set tmp creg
    gctag \tmp, \creg
    beqz \tmp, failure
.endm

.macro expect_cap_equal tmp creg1 creg2
    sceq \tmp, \creg1, \creg2
    beqz \tmp, failure
.endm

.macro expect_tag_unset tmp creg
    gctag \tmp, \creg
    bnez \tmp, failure
.endm

.section .text

// Test for capability tags.
.global _start
_start:
    csrsi mseccfg, (1 << 3)
    modesw.cap

    // Get capability to storage in ct0.
    llc ct0, storage

    // Check that tags start out unset.
    clc ct1, 0(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 16(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 32(ct0)
    expect_tag_unset t2, ct1

    // Store valid capabilities.
    csc ct0, 0(ct0)
    csc ct0, 16(ct0)
    csc ct0, 32(ct0)

    // Check that capability read is same as written.
    clc ct1, 0(ct0)
    expect_cap_equal t2, ct0, ct1
    clc ct1, 16(ct0)
    expect_cap_equal t2, ct0, ct1
    clc ct1, 32(ct0)
    expect_cap_equal t2, ct0, ct1

    // Invalidate the second capability with write to least significant word.
    csw zero,16(ct0)

    // Check that only second capability tag bit is unset.
    clc ct1, 0(ct0)
    expect_tag_set t2, ct1
    clc ct1, 16(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 32(ct0)
    expect_tag_set t2, ct1

    // Write back valid capability.
    csc ct0, 16(ct0)

    // Invalidate the second capability with write to a middle byte.
    csb zero, 23(ct0)

    // Check that only second capability tag bit is unset.
    clc ct1, 0(ct0)
    expect_tag_set t2, ct1
    clc ct1, 16(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 32(ct0)
    expect_tag_set t2, ct1

    // Invalidate the other two capabilities.
    csh zero, 4(ct0)
    csd zero, 32(ct0)

    // Check that tags are all unset.
    clc ct1, 0(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 16(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 32(ct0)
    expect_tag_unset t2, ct1

    // Store valid capabilities.
    csc ct0, 0(ct0)
    csc ct0, 16(ct0)
    csc ct0, 32(ct0)

    // Check that tags are all set.
    clc ct1, 0(ct0)
    expect_tag_set t2, ct1
    clc ct1, 16(ct0)
    expect_tag_set t2, ct1
    clc ct1, 32(ct0)
    expect_tag_set t2, ct1

    // Store a null cap to the second capability.
    csc cnull ,16(ct0)

    // Invalidate the third capability by writing to most significant word.
    csw zero, 44(ct0)

    // Check that only the first capability tag bit is set.
    clc ct1, 0(ct0)
    expect_tag_set t2, ct1
    clc ct1, 16(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 32(ct0)
    expect_tag_unset t2, ct1

    // Store valid capabilities.
    csc ct0, 0(ct0)
    csc ct0, 16(ct0)
    csc ct0, 32(ct0)

    // Check that all tags are set.
    clc ct1,  0(ct0)
    expect_tag_set t2, ct1
    clc ct1, 16(ct0)
    expect_tag_set t2, ct1
    clc ct1, 32(ct0)
    expect_tag_set t2, ct1

    // Invalidate the first capability by writing to most significant half word.
    csh zero,14(ct0)
    // Invalidate the third capability by writing to most significant byte.
    csb zero,47(ct0)

    // Check that only the second capability tag bit is set.
    clc ct1, 0(ct0)
    expect_tag_unset t2, ct1
    clc ct1, 16(ct0)
    expect_tag_set t2, ct1
    clc ct1, 32(ct0)
    expect_tag_unset t2, ct1

    // Success!
    j success

success:
    j success
failure:
    j failure

.p2align 7
storage:
.zero 64 // Four capabilities of 16 bytes each.
