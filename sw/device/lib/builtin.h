// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

/* array length macro */
#define ARRAY_LEN(array) (sizeof(array) / sizeof((array)[0]))

/* inline assembly */
#define asm __asm__

/* count trailing zeroes */
#define ctz(x) (__builtin_ctz((x)))

/* checked arithmetic intrinsics
 * these return true if x op y causes overflow */
#define uaddl_overflow(x, y, sum)  (__builtin_uaddl_overflow((x), (y), (sum)))
#define umull_overflow(x, y, prod) (__builtin_umull_overflow((x), (y), (prod)))
