// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/rstmgr.h"
#include <stdbool.h>
#include <stdint.h>

bool test_main()
{
    rstmgr_t rstmgr = mocha_system_rstmgr();
    uint32_t reset_reason = rstmgr_reset_reason_get(rstmgr);

    if (reset_reason & RSTMGR_RESET_INFO_POR) {
        rstmgr_reset_reason_clear(rstmgr, RSTMGR_RESET_INFO_POR);

#if defined(__CHERI_PURE_CAPABILITY__)
        uint64_t res1, res2, res3, res4;

        __asm__ volatile(
            // Get capability to storage area at the start of AXI SRAM in t0.
            "auipc t0, 0\n\t"
            "yaddrw t0, t0, %4\n\t"

            // Store valid capabilities.
            "sy t0, 0(t0)\n\t"
            "sy t0, 16(t0)\n\t"
            "sy t0, 32(t0)\n\t"
            "sy t0, 48(t0)\n\t"
            "fence\n\t"

            // Check that all capability tag bits are set.
            "ly t1, 0(t0)\n\t"
            "ytagr %0, t1\n\t"
            "ly t1, 16(t0)\n\t"
            "ytagr %1, t1\n\t"
            "ly t1, 32(t0)\n\t"
            "ytagr %2, t1\n\t"
            "ly t1, 48(t0)\n\t"
            "ytagr %3, t1\n\t"

            : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4)
            : "r"(( // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
                uint64_t)sram_base)
            : "t1", "t0", "memory");
        if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 != 0)) {
            return false;
        }

        __asm__ volatile(
            // Get capability to storage area at the end of AXI SRAM in t0.
            "auipc t0, 0\n\t"
            "yaddrw t0, t0, %4\n\t"

            // Store valid capabilities.
            "sy t0, 0(t0)\n\t"
            "sy t0, 16(t0)\n\t"
            "sy t0, 32(t0)\n\t"
            "sy t0, 48(t0)\n\t"
            "fence\n\t"

            // Check that all capability tag bits are set.
            "ly t1, 0(t0)\n\t"
            "ytagr %0, t1\n\t"
            "ly t1, 16(t0)\n\t"
            "ytagr %1, t1\n\t"
            "ly t1, 32(t0)\n\t"
            "ytagr %2, t1\n\t"
            "ly t1, 48(t0)\n\t"
            "ytagr %3, t1\n\t"

            : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4)
            : "r"(( // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
                      uint64_t)sram_base +
                  sram_length - 64)
            : "t1", "t0", "memory");
        if (!(res1 != 0 && res2 != 0 && res3 != 0 && res4 != 0)) {
            return false;
        }
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

        rstmgr_software_reset_request(rstmgr);

        // Must wait here for reset to happen.
        while (1) {
        }
    }

    if (reset_reason & RSTMGR_RESET_INFO_SW_RESET) {
        rstmgr_reset_reason_clear(rstmgr, RSTMGR_RESET_INFO_SW_RESET);

#if defined(__CHERI_PURE_CAPABILITY__)
        uint64_t res1, res2, res3, res4;

        __asm__ volatile(
            // Get capability to storage area at the start of AXI SRAM in t0.
            "auipc t0, 0\n\t"
            "yaddrw t0, t0, %4\n\t"

            // Check that all capability tag bits are unset.
            "ly t1, 0(t0)\n\t"
            "ytagr %0, t1\n\t"
            "ly t1, 16(t0)\n\t"
            "ytagr %1, t1\n\t"
            "ly t1, 32(t0)\n\t"
            "ytagr %2, t1\n\t"
            "ly t1, 48(t0)\n\t"
            "ytagr %3, t1\n\t"

            : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4)
            : "r"(( // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
                uint64_t)sram_base)
            : "t1", "t0", "memory");
        if (!(res1 == 0 && res2 == 0 && res3 == 0 && res4 == 0)) {
            return false;
        }

        __asm__ volatile(
            // Get capability to storage area at the end of AXI SRAM in t0.
            "auipc t0, 0\n\t"
            "yaddrw t0, t0, %4\n\t"

            // Check that all capability tag bits are unset.
            "ly t1, 0(t0)\n\t"
            "ytagr %0, t1\n\t"
            "ly t1, 16(t0)\n\t"
            "ytagr %1, t1\n\t"
            "ly t1, 32(t0)\n\t"
            "ytagr %2, t1\n\t"
            "ly t1, 48(t0)\n\t"
            "ytagr %3, t1\n\t"

            : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4)
            : "r"(( // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
                      uint64_t)sram_base +
                  sram_length - 64)
            : "t1", "t0", "memory");
        if (!(res1 == 0 && res2 == 0 && res3 == 0 && res4 == 0)) {
            return false;
        }
#endif /* defined(__CHERI_PURE_CAPABILITY__) */

        return true;
    }

    return false;
}
