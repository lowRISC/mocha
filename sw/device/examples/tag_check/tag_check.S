# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

.section .text

// Test for capability tags
.global _start
_start:
  csrsi mseccfg, (1 << 3)
  modesw.cap
  // Get capability to storage in ct0.
  llc ct0, storage
  // Check that tags start out as 0.
  clc ct1,  0(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  bnez t2, fail
  // Store valid capabilities.
  csc ct0,  0(ct0)
  csc ct0, 16(ct0)
  csc ct0, 32(ct0)
  // Check that tags are all valid.
  clc ct1,  0(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  beqz t2, fail
  // Invalidate the second capability with write to least significant word.
  csw zero,16(ct0)
  // Check tags are 1,0,1.
  clc ct1,  0(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  beqz t2, fail
  // Write back valid capability.
  csc ct0, 16(ct0)
  // Invalidate the second capability with write to a middle byte.
  csb zero,23(ct0)
  // Check that tags are 1,0,1.
  clc ct1,  0(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  beqz t2, fail
  // Invalidate the other two capabilities.
  csh zero, 4(ct0)
  csd zero,32(ct0)
  // Check that tags are all invalid.
  clc ct1,  0(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  bnez t2, fail
  // Store valid capabilities.
  csc ct0,  0(ct0)
  csc ct0, 16(ct0)
  csc ct0, 32(ct0)
  // Check that tags are all valid.
  clc ct1,  0(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  beqz t2, fail
  // Store a null cap to the second capability.
  csc cnull,16(ct0)
  // Invalidate the third capability by writing to most significant word.
  csw zero, 44(ct0)
  // Check that tags are 1,0,0.
  clc ct1,  0(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  bnez t2, fail
  // Store valid capabilities.
  csc ct0,  0(ct0)
  csc ct0, 16(ct0)
  csc ct0, 32(ct0)
  // Check that tags are all valid.
  clc ct1,  0(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  beqz t2, fail
  // Invalidate the first capability by writing to most significant half word.
  csh zero,14(ct0)
  // Invalidate the third capability by writing to most significant byte.
  csb zero,47(ct0)
  // Check that tags are 0,1,0.
  clc ct1,  0(ct0)
  gctag t2, ct1
  bnez t2, fail
  clc ct1, 16(ct0)
  gctag t2, ct1
  beqz t2, fail
  clc ct1, 32(ct0)
  gctag t2, ct1
  bnez t2, fail

success:
  j success

.p2align 7
storage:
.zero 64 // Four capabilities of 16 bytes each.

// If we get here we know something went wrong.
fail:
  j fail
