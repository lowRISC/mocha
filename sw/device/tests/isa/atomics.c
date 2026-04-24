// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "builtin.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

bool atomic_swap32_test(void)
{
    uint32_t a[4] = { 0xaaaaaaaau, 0x55555555u, 0xff00ff00u, 0xffff0000u };
    uint32_t b[4] = { 0x55555555u, 0xaaaaaaaau, 0x00ff00ffu, 0x0000ffffu };
    uint32_t x[4], y[4];

    for (size_t i = 0; i < 4; i++) {
        x[i] = a[i];
        y[i] = b[i];
    }

    for (size_t i = 0; i < 4; i++) {
        uint32_t ret;
        asm volatile("amoswap.w.aqrl %0, %2, %1\n" : "=r"(ret), "+A"(x[i]) : "r"(y[i]) : "memory");
        y[i] = ret;
    }

    for (size_t i = 0; i < 4; i++) {
        if (x[i] != b[i]) {
            return false;
        }
        if (y[i] != a[i]) {
            return false;
        }
    }

    return true;
}

bool atomic_swap64_test(void)
{
    uint64_t a[4] = { 0xaaaaaaaaaaaaaaaaul, 0x5555555555555555ul, 0xff00ff00ff00ff00ul,
                      0xffff0000ffff0000ul };
    uint64_t b[4] = { 0x5555555555555555ul, 0xaaaaaaaaaaaaaaaaul, 0x00ff00ff00ff00fful,
                      0x0000ffff0000fffful };
    uint64_t x[4], y[4];

    for (size_t i = 0; i < 4; i++) {
        x[i] = a[i];
        y[i] = b[i];
    }

    for (size_t i = 0; i < 4; i++) {
        uint64_t ret;
        asm volatile("amoswap.d.aqrl %0, %2, %1\n" : "=r"(ret), "+A"(x[i]) : "r"(y[i]) : "memory");
        y[i] = ret;
    }

    for (size_t i = 0; i < 4; i++) {
        if (x[i] != b[i]) {
            return false;
        }
        if (y[i] != a[i]) {
            return false;
        }
    }

    return true;
}

bool test_main(void)
{
    return atomic_swap32_test() && atomic_swap64_test();
}
