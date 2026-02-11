// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "runtime/string.h"
#include <stddef.h>
#include <stdint.h>

void *memcpy(void *restrict dest, const void *restrict src, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        ((uint8_t *)dest)[i] = ((uint8_t *)src)[i];
    }
    return dest;
}

void *memset(void *dest, uint8_t v, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        ((uint8_t *)dest)[i] = v;
    }
    return dest;
}

size_t strlen(const char *str)
{
    size_t i = 0;
    while (str[i] != '\0') {
        i++;
    }
    return i;
}
