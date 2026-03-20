// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

bool tag_test()
{
#if defined(__riscv_zcherihybrid)
    uint64_t res1, res2, res3, res4, res5, res6, res7, res8, res9, res10, res11, res12, res13,
        res14, res15;

    __asm__ volatile(
        "j test_start\n\t"

        // Capability storage.
        ".p2align 7\n\t"
        "storage:\n\t"
        ".zero 64\n\t" // Four capabilities of 16 bytes each.

        // Get capability to storage in ct0.
        "test_start: llc ct0, storage\n\t"

        // Check that tags start out unset.
        "clc ct1, 0(ct0)\n\t"
        "gctag %0, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %1, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %2, ct1\n\t"

        // Store valid capabilities.
        "csc ct0, 0(ct0)\n\t"
        "csc ct0, 16(ct0)\n\t"
        "csc ct0, 32(ct0)\n\t"
        "fence\n\t"

        // Check that capability read is same as written.
        "clc ct1, 0(ct0)\n\t"
        "sceq %3, ct0, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "sceq %4, ct0, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "sceq %5, ct0, ct1\n\t"

        // Invalidate the second capability with write to least significant word.
        "csw zero, 16(ct0)\n\t"
        "fence\n\t"

        // Check that only second capability tag bit is unset.
        "clc ct1, 0(ct0)\n\t"
        "gctag %6, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %7, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %8, ct1\n\t"

        // Write back valid capability.
        "csc ct0, 16(ct0)\n\t"
        // Invalidate the second capability with write to a middle byte.
        "csb zero, 23(ct0)\n\t"
        "fence\n\t"

        // Check that only second capability tag bit is unset.
        "clc ct1, 0(ct0)\n\t"
        "gctag %9, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %10, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %11, ct1\n\t"

        // Invalidate the other two capabilities.
        "csh zero, 4(ct0)\n\t"
        "csd zero, 32(ct0)\n\t"
        "fence\n\t"

        // Check that tags are all unset.
        "clc ct1, 0(ct0)\n\t"
        "gctag %12, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %13, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %14, ct1\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6), "=r"(res7),
          "=r"(res8), "=r"(res9), "=r"(res10), "=r"(res11), "=r"(res12), "=r"(res13), "=r"(res14),
          "=r"(res15)
        :
        : "ct1", "ct0", "memory");
    if (!(res1 == 0 && res2 == 0 && res3 == 0 && res4 != 0 && res5 != 0 && res6 != 0 && res7 != 0 &&
          res8 == 0 && res9 != 0 && res10 != 0 && res11 == 0 && res12 != 0 && res13 == 0 &&
          res14 == 0 && res15 == 0)) {
        return false;
    }

    __asm__ volatile(
        // Get capability to storage in ct0.
        "llc ct0, storage\n\t"

        // Store valid capabilities.
        "csc ct0, 0(ct0)\n\t"
        "csc ct0, 16(ct0)\n\t"
        "csc ct0, 32(ct0)\n\t"
        "fence\n\t"

        // Check that tags are all set.
        "clc ct1, 0(ct0)\n\t"
        "gctag %0, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %1, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %2, ct1\n\t"

        // Store a null cap to the second capability.
        "csc cnull, 16(ct0)\n\t"
        // Invalidate the third capability by writing to most significant word.
        "csw zero, 44(ct0)\n\t"
        "fence\n\t"

        // Check that only the first capability tag bit is set.
        "clc ct1, 0(ct0)\n\t"
        "gctag %3, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %4, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %5, ct1\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6)
        :
        : "ct1", "ct0", "memory");
    if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 != 0 && res5 == 0 && res6 == 0)) {
        return false;
    }

    __asm__ volatile(
        // Get capability to storage in ct0.
        "llc ct0, storage\n\t"

        // Store valid capabilities.
        "csc ct0, 0(ct0)\n\t"
        "csc ct0, 16(ct0)\n\t"
        "csc ct0, 32(ct0)\n\t"
        "fence\n\t"

        // Check that all tags are set.
        "clc ct1, 0(ct0)\n\t"
        "gctag %0, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %1, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %2, ct1\n\t"

        // Invalidate the first capability by writing to most significant half word.
        "csh zero, 14(ct0)\n\t"
        // Invalidate the third capability by writing to most significant byte.
        "csb zero, 47(ct0)\n\t"
        "fence\n\t"

        // Check that only the second capability tag bit is set.
        "clc ct1, 0(ct0)\n\t"
        "gctag %3, ct1\n\t"
        "clc ct1, 16(ct0)\n\t"
        "gctag %4, ct1\n\t"
        "clc ct1, 32(ct0)\n\t"
        "gctag %5, ct1\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6)
        :
        : "ct1", "ct0", "memory");
    if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 == 0 && res5 != 0 && res6 == 0)) {
        return false;
    }
#endif /* defined(__riscv_zcherihybrid) */

    return true;
}

bool test_main()
{
    return tag_test();
}
