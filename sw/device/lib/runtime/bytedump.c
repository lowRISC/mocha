// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "runtime/print.h"

char printable_or_dot(uint8_t byte)
{
    return (byte >= 0x20u && byte < 0x80u) ? byte : '.';
}

void uart_dump_bytes(uart_t uart, const uint8_t buf[], size_t len)
{
    uint8_t byte_store[4];
    uint32_t *word_store = (uint32_t *)byte_store;
    *word_store = 0u;
    for (size_t off = 0u; off < len; ++off) {
        // Currently, uprintf() cannot print hex values smaller than four bytes
        // without padding with zeros, so accumulate four bytes chunks for it.
        byte_store[off & 0x3u] = buf[off];
        if ((off & 0x3u) == 0x3u || off == (len - 1)) {
            uprintf(uart, "%x", *word_store);
            *word_store = 0u; // clear in case less than four bytes remain
            if ((off & 0xfu) == 0xfu || off == (len - 1)) {
                uprintf(uart, " : ");
                for (size_t aoff = (off & ~0xfu); aoff <= off; aoff++) {
                    uprintf(uart, "%c", printable_or_dot(buf[aoff]));
                }
                uprintf(uart, "\n");
            } else {
                uprintf(uart, " ");
            }
        }
    }
}
