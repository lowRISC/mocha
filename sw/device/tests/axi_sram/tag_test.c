// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include <stdbool.h>
#include <stdint.h>

bool tag_test()
{
#if defined(__CHERI_PURE_CAPABILITY__)
    uint64_t res1, res2, res3, res4, res5, res6, res7, res8, res9, res10, res11, res12, res13,
        res14, res15;

    __asm__ volatile(
        "j test_start\n\t"

        // Capability storage.
        ".p2align 7\n\t"
        "storage:\n\t"
        ".zero 64\n\t" // Four capabilities of 16 bytes each.

        // Get capability to storage in t0.
        "test_start: lly t0, storage\n\t"

        // Check that tags start out unset.
        "ly t1, 0(t0)\n\t"
        "ytagr %0, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %1, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %2, t1\n\t"

        // Store valid capabilities.
        "sy t0, 0(t0)\n\t"
        "sy t0, 16(t0)\n\t"
        "sy t0, 32(t0)\n\t"
        "fence\n\t"

        // Check that capability read is same as written.
        "ly t1, 0(t0)\n\t"
        "yeq %3, t0, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "yeq %4, t0, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "yeq %5, t0, t1\n\t"

        // Invalidate the second capability with write to least significant word.
        "sw zero, 16(t0)\n\t"
        "fence\n\t"

        // Check that only second capability tag bit is unset.
        "ly t1, 0(t0)\n\t"
        "ytagr %6, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %7, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %8, t1\n\t"

        // Write back valid capability.
        "sy t0, 16(t0)\n\t"
        // Invalidate the second capability with write to a middle byte.
        "sb zero, 23(t0)\n\t"
        "fence\n\t"

        // Check that only second capability tag bit is unset.
        "ly t1, 0(t0)\n\t"
        "ytagr %9, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %10, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %11, t1\n\t"

        // Invalidate the other two capabilities.
        "sh zero, 4(t0)\n\t"
        "sd zero, 32(t0)\n\t"
        "fence\n\t"

        // Check that tags are all unset.
        "ly t1, 0(t0)\n\t"
        "ytagr %12, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %13, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %14, t1\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6), "=r"(res7),
          "=r"(res8), "=r"(res9), "=r"(res10), "=r"(res11), "=r"(res12), "=r"(res13), "=r"(res14),
          "=r"(res15)
        :
        : "t1", "t0", "memory");
    if (!(res1 == 0 && res2 == 0 && res3 == 0 && res4 != 0 && res5 != 0 && res6 != 0 && res7 != 0 &&
          res8 == 0 && res9 != 0 && res10 != 0 && res11 == 0 && res12 != 0 && res13 == 0 &&
          res14 == 0 && res15 == 0)) {
        return false;
    }

    __asm__ volatile(
        // Get capability to storage in t0.
        "lly t0, storage\n\t"

        // Store valid capabilities.
        "sy t0, 0(t0)\n\t"
        "sy t0, 16(t0)\n\t"
        "sy t0, 32(t0)\n\t"
        "fence\n\t"

        // Check that tags are all set.
        "ly t1, 0(t0)\n\t"
        "ytagr %0, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %1, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %2, t1\n\t"

        // Store a null cap to the second capability.
        "sy zero, 16(t0)\n\t"
        // Invalidate the third capability by writing to most significant word.
        "sw zero, 44(t0)\n\t"
        "fence\n\t"

        // Check that only the first capability tag bit is set.
        "ly t1, 0(t0)\n\t"
        "ytagr %3, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %4, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %5, t1\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6)
        :
        : "t1", "t0", "memory");
    if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 != 0 && res5 == 0 && res6 == 0)) {
        return false;
    }

    __asm__ volatile(
        // Get capability to storage in t0.
        "lly t0, storage\n\t"

        // Store valid capabilities.
        "sy t0, 0(t0)\n\t"
        "sy t0, 16(t0)\n\t"
        "sy t0, 32(t0)\n\t"
        "fence\n\t"

        // Check that all tags are set.
        "ly t1, 0(t0)\n\t"
        "ytagr %0, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %1, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %2, t1\n\t"

        // Invalidate the first capability by writing to most significant half word.
        "sh zero, 14(t0)\n\t"
        // Invalidate the third capability by writing to most significant byte.
        "sb zero, 47(t0)\n\t"
        "fence\n\t"

        // Check that only the second capability tag bit is set.
        "ly t1, 0(t0)\n\t"
        "ytagr %3, t1\n\t"
        "ly t1, 16(t0)\n\t"
        "ytagr %4, t1\n\t"
        "ly t1, 32(t0)\n\t"
        "ytagr %5, t1\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6)
        :
        : "t1", "t0", "memory");
    if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 == 0 && res5 != 0 && res6 == 0)) {
        return false;
    }
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

    return true;
}

bool test_main()
{
    return tag_test();
}
