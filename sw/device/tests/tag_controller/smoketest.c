// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

bool data_readback_test(void *dram)
{
    // Lowest address
    DEV_WRITE(dram + 0, 0x55AA12EF);
    if (DEV_READ(dram + 0) != 0x55AA12EF) {
        return false;
    }

    // Highest address
    DEV_WRITE(dram + 0x3F800000 - 4, 0x55AA11EE);
    if (DEV_READ(dram + 0x3F800000 - 4) != 0x55AA11EE) {
        return false;
    }

    DEV_WRITE8(dram + 0x3F800000 - 1, 0xA5);
    if (DEV_READ8(dram + 0x3F800000 - 1) != 0xA5) {
        return false;
    }

    // Varying sizes
    DEV_WRITE8(dram + 5, 0x5A);
    if (DEV_READ8(dram + 5) != 0x5A) {
        return false;
    }

    DEV_WRITE16(dram + 10, 0xF1A5);
    if (DEV_READ16(dram + 10) != 0xF1A5) {
        return false;
    }

    DEV_WRITE64(dram + 24, 0xF1A5FF4411AA5577);
    if (DEV_READ64(dram + 24) != 0xF1A5FF4411AA5577) {
        return false;
    }

    return true;
}

bool rapid_write_test()
{
    uint64_t d1 = 0xB03747F359ABBCFEUL, res1;
    uint64_t d2 = 0x0A197F0071E028A1UL, res2;
    uint64_t d3 = 0x2F8A98EBDE49CBE5UL, res3;
    uint64_t d4 = 0x4941BC77DFF95D5BUL, res4;
    uint64_t d5 = 0xF37781A1BC0B12E5UL, res5;
    uint64_t d6 = 0x5FA5C302A0F3B761UL, res6;
    uint64_t d7 = 0xE18D4B4FBDA05B40UL, res7;
    uint64_t d8 = 0x0E918F4F7B4F4F31UL, res8;

    // Using inline assembly to keep writes and reads back-to-back
#if defined(__riscv_zcherihybrid)
    __asm__ volatile(
        // Get capability to dram in ct0.
        "auipc ct0, 0\n\t"
        "scaddr ct0, ct0, %16\n\t"

        // Writes
        "sd %8, 0(ct0)\n\t"
        "sd %9, 8(ct0)\n\t"
        "sd %10, 16(ct0)\n\t"
        "sd %11, 24(ct0)\n\t"
        "sd %12, 32(ct0)\n\t"
        "sd %13, 40(ct0)\n\t"
        "sd %14, 48(ct0)\n\t"
        "sd %15, 56(ct0)\n\t"

        // Reads
        "ld %0, 0(ct0)\n\t"
        "ld %1, 8(ct0)\n\t"
        "ld %2, 16(ct0)\n\t"
        "ld %3, 24(ct0)\n\t"
        "ld %4, 32(ct0)\n\t"
        "ld %5, 40(ct0)\n\t"
        "ld %6, 48(ct0)\n\t"
        "ld %7, 56(ct0)\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6), "=r"(res7),
          "=r"(res8)
        : "r"(d1), "r"(d2), "r"(d3), "r"(d4), "r"(d5), "r"(d6), "r"(d7), "r"(d8),
          "r"((uint64_t)dram_base) // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
        : "ct0", "memory");
#else /* !defined(__riscv_zcherihybrid) */
    __asm__ volatile(
        // Get pointer to dram t0.
        "mv t0, %16\n\t"

        // Writes
        "sd %8, 0(t0)\n\t"
        "sd %9, 8(t0)\n\t"
        "sd %10, 16(t0)\n\t"
        "sd %11, 24(t0)\n\t"
        "sd %12, 32(t0)\n\t"
        "sd %13, 40(t0)\n\t"
        "sd %14, 48(t0)\n\t"
        "sd %15, 56(t0)\n\t"

        // Reads
        "ld %0, 0(t0)\n\t"
        "ld %1, 8(t0)\n\t"
        "ld %2, 16(t0)\n\t"
        "ld %3, 24(t0)\n\t"
        "ld %4, 32(t0)\n\t"
        "ld %5, 40(t0)\n\t"
        "ld %6, 48(t0)\n\t"
        "ld %7, 56(t0)\n\t"
        : "=r"(res1), "=r"(res2), "=r"(res3), "=r"(res4), "=r"(res5), "=r"(res6), "=r"(res7),
          "=r"(res8)
        : "r"(d1), "r"(d2), "r"(d3), "r"(d4), "r"(d5), "r"(d6), "r"(d7), "r"(d8),
          "r"((uint64_t)dram_base) // NOLINT(cheri-PtrToIntCast): Need a uint to load into register
        : "t0", "memory");
#endif /* defined(__riscv_zcherihybrid) */

    if (d1 != res1 || d2 != res2 || d3 != res3 || d4 != res4 || d5 != res5 || d6 != res6 ||
        d7 != res7 || d8 != res8) {
        return false;
    }

    return true;
}

bool partial_write_test(void *dram)
{
    // 32-bit partial write
    DEV_WRITE64(dram + 104, 0xAB29E436334802BDUL);
    DEV_WRITE(dram + 108, 0xFFEE55AA);
    if (DEV_READ64(dram + 104) != 0xFFEE55AA334802BD) {
        return false;
    }

    // 16-bit partial write
    DEV_WRITE64(dram + 152, 0xF74A1BA9CDAE7BC4UL);
    DEV_WRITE16(dram + 152, 0x55AA);
    if (DEV_READ64(dram + 152) != 0xF74A1BA9CDAE55AA) {
        return false;
    }

    // 8-bit partial write
    DEV_WRITE64(dram + 416, 0xD2BE40DEAE45E33DUL);
    DEV_WRITE8(dram + 419, 0xA5);
    if (DEV_READ64(dram + 416) != 0xD2BE40DEA545E33DUL) {
        return false;
    }

    return true;
}

bool sparse_write_test(void *dram)
{
    for (int i = 0; i < 150; ++i) {
        DEV_WRITE64(dram + i * (887759 * 8), 0x55AA15CFEEBB0033);
    }
    for (int i = 0; i < 150; ++i) {
        if (DEV_READ64(dram + i * (887759 * 8)) != 0x55AA15CFEEBB0033) {
            return false;
        }
    }

    return true;
}

bool test_main()
{
    void *dram = mocha_system_dram();

    return data_readback_test(dram) && rapid_write_test() && partial_write_test(dram) &&
           sparse_write_test(dram);
}
