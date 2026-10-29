// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

enum {
    evict_test_capabilities = 32u,
};

bool tag_test()
{
#if defined(__CHERI_PURE_CAPABILITY__)
    // Using lots of registers for passing results to make sure memory accesses are rapid
    // enough to reveal a known bug in the tag controller that have since been worked around.
    uint64_t res1, res2, res3, res4, res5, res6, res7, res8, res9, res10, res11, res12, res13,
        res14, res15;

    asm volatile(
        // Get capability to dram in t0.
        "auipc t0, 0\n\t"
        "yaddrw t0, t0, %15\n\t"

        // Write words to invalidate tags.
        "sw zero, 0(t0)\n\t"
        "sw zero, 16(t0)\n\t"
        "sw zero, 32(t0)\n\t"
        "fence\n\t"

        // Check that tags are unset.
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
        : "r"((uint64_t)dram_base) // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
        : "t1", "t0", "memory");
    if (!(res1 == 0 && res2 == 0 && res3 == 0 && res4 != 0 && res5 != 0 && res6 != 0 && res7 != 0 &&
          res8 == 0 && res9 != 0 && res10 != 0 && res11 == 0 && res12 != 0 && res13 == 0 &&
          res14 == 0 && res15 == 0)) {
        return false;
    }

    asm volatile(
        // Get capability to dram in t0.
        "auipc t0, 0\n\t"
        "yaddrw t0, t0, %6\n\t"

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
        : "r"((uint64_t)dram_base) // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
        : "t1", "t0", "memory");
    if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 != 0 && res5 == 0 && res6 == 0)) {
        return false;
    }

    asm volatile(
        // Get capability to dram in t0.
        "auipc t0, 0\n\t"
        "yaddrw t0, t0, %6\n\t"

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
        : "r"((uint64_t)dram_base) // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
        : "t1", "t0", "memory");
    if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 == 0 && res5 != 0 && res6 == 0)) {
        return false;
    }
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

    return true;
}

#if defined(__CHERI_PURE_CAPABILITY__)
void write_valid_cap(const uint64_t addr)
{
    asm volatile(
        // Get capability to address.
        "auipc t0, 0\n\t"
        "yaddrw t0, t0, %0\n\t"

        // Store valid capability.
        "sy t0, 0(t0)\n\t"
        "fence\n\t"
        :
        : "r"(addr)
        : "t0", "memory");
}

void write_invalid_cap(const uint64_t addr)
{
    asm volatile(
        // Get capability to address.
        "auipc t0, 0\n\t"
        "yaddrw t0, t0, %0\n\t"

        // Store invalid capability.
        "sy zero, 0(t0)\n\t"
        "fence\n\t"
        :
        : "r"(addr)
        : "t0", "memory");
}

bool cap_is_valid(const uint64_t addr)
{
    uint64_t res;

    asm volatile(
        // Get capability to address.
        "auipc t0, 0\n\t"
        "yaddrw t0, t0, %1\n\t"

        // Check if tag is set.
        "ly t1, 0(t0)\n\t"
        "ytagr %0, t1\n\t"
        : "=r"(res)
        : "r"(addr)
        : "t0", "t1");

    return res != 0;
}
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

bool tag_cache_evict_test()
{
#if defined(__CHERI_PURE_CAPABILITY__)
    for (int i = 0; i < evict_test_capabilities; ++i) {
        write_valid_cap(0x81000000UL + (i << 24));
    }

    for (int i = 0; i < evict_test_capabilities; ++i) {
        if (!cap_is_valid(0x81000000UL + (i << 24))) {
            return false;
        }
    }

    for (int i = 0; i < evict_test_capabilities; ++i) {
        if ((i & 1) == 1) {
            write_invalid_cap(0x81000000UL + (i << 24));
        }
    }

    for (int i = 0; i < evict_test_capabilities; ++i) {
        if ((i & 1) == 0) {
            if (!cap_is_valid(0x81000000UL + (i << 24))) {
                return false;
            }
        } else {
            if (cap_is_valid(0x81000000UL + (i << 24))) {
                return false;
            }
        }
    }
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

    return true;
}

bool test_main()
{
    return tag_test() && tag_cache_evict_test();
}
