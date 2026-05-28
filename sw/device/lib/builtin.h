// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdint.h>

/* array length macro */
#define ARRAY_LEN(array) (sizeof(array) / sizeof((array)[0]))

/* inline assembly */
#define asm __asm__

/* count trailing zeroes */
#define ctz(x)   (__builtin_ctz((x)))
#define ctzll(x) (__builtin_ctzll((x)))
/* count leading zeroes */
#define clz(x)   (__builtin_clz((x)))
#define clzll(x) (__builtin_clzll((x)))

/* floor log2 32-bit */
static inline uint32_t ilog2(uint32_t x)
{
    return (x == 0u) ? 0u : (32u - clz(x) - 1u);
}
/* floor log2 64-bit */
static inline uint32_t ilog2ll(uint64_t x)
{
    return (x == 0ull) ? 0u : (64u - clzll(x) - 1u);
}

/* checked arithmetic intrinsics
 * these return true if x op y causes overflow */
#define uaddl_overflow(x, y, sum)  (__builtin_uaddl_overflow((x), (y), (sum)))
#define umull_overflow(x, y, prod) (__builtin_umull_overflow((x), (y), (prod)))
