# Copyright lowRISC and contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

.macro expect_tag_set tmp creg
    ytagr \tmp, \creg
    beqz \tmp, failure
.endm

.macro expect_cap_equal tmp creg1 creg2
    yeq \tmp, \creg1, \creg2
    beqz \tmp, failure
.endm

.macro expect_tag_unset tmp creg
    ytagr \tmp, \creg
    bnez \tmp, failure
.endm

.section .text

// Test for capability tags.
.global _start
_start:
    ymodeswy

    // Get capability to storage in t0.
    lly t0, storage

    // Check that tags start out unset.
    ly t1, 0(t0)
    expect_tag_unset t2, t1
    ly t1, 16(t0)
    expect_tag_unset t2, t1
    ly t1, 32(t0)
    expect_tag_unset t2, t1

    // Store valid capabilities.
    sy t0, 0(t0)
    sy t0, 16(t0)
    sy t0, 32(t0)

    // Check that capability read is same as written.
    ly t1, 0(t0)
    expect_cap_equal t2, t0, t1
    ly t1, 16(t0)
    expect_cap_equal t2, t0, t1
    ly t1, 32(t0)
    expect_cap_equal t2, t0, t1

    // Invalidate the second capability with write to least significant word.
    sw zero,16(t0)

    // Check that only second capability tag bit is unset.
    ly t1, 0(t0)
    expect_tag_set t2, t1
    ly t1, 16(t0)
    expect_tag_unset t2, t1
    ly t1, 32(t0)
    expect_tag_set t2, t1

    // Write back valid capability.
    sy t0, 16(t0)

    // Invalidate the second capability with write to a middle byte.
    sb zero, 23(t0)

    // Check that only second capability tag bit is unset.
    ly t1, 0(t0)
    expect_tag_set t2, t1
    ly t1, 16(t0)
    expect_tag_unset t2, t1
    ly t1, 32(t0)
    expect_tag_set t2, t1

    // Invalidate the other two capabilities.
    sh zero, 4(t0)
    sd zero, 32(t0)

    // Check that tags are all unset.
    ly t1, 0(t0)
    expect_tag_unset t2, t1
    ly t1, 16(t0)
    expect_tag_unset t2, t1
    ly t1, 32(t0)
    expect_tag_unset t2, t1

    // Store valid capabilities.
    sy t0, 0(t0)
    sy t0, 16(t0)
    sy t0, 32(t0)

    // Check that tags are all set.
    ly t1, 0(t0)
    expect_tag_set t2, t1
    ly t1, 16(t0)
    expect_tag_set t2, t1
    ly t1, 32(t0)
    expect_tag_set t2, t1

    // Store a null cap to the second capability.
    sy zero ,16(t0)

    // Invalidate the third capability by writing to most significant word.
    sw zero, 44(t0)

    // Check that only the first capability tag bit is set.
    ly t1, 0(t0)
    expect_tag_set t2, t1
    ly t1, 16(t0)
    expect_tag_unset t2, t1
    ly t1, 32(t0)
    expect_tag_unset t2, t1

    // Store valid capabilities.
    sy t0, 0(t0)
    sy t0, 16(t0)
    sy t0, 32(t0)

    // Check that all tags are set.
    ly t1,  0(t0)
    expect_tag_set t2, t1
    ly t1, 16(t0)
    expect_tag_set t2, t1
    ly t1, 32(t0)
    expect_tag_set t2, t1

    // Invalidate the first capability by writing to most significant half word.
    sh zero,14(t0)
    // Invalidate the third capability by writing to most significant byte.
    sb zero,47(t0)

    // Check that only the second capability tag bit is set.
    ly t1, 0(t0)
    expect_tag_unset t2, t1
    ly t1, 16(t0)
    expect_tag_set t2, t1
    ly t1, 32(t0)
    expect_tag_unset t2, t1

    // Success!
    j success

success:
    j success
failure:
    j failure

.p2align 7
storage:
.zero 64 // Four capabilities of 16 bytes each.
