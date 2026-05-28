// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include <stddef.h>
#include <stdint.h>

// Return the provided byte if it is a printable character, or '.' otherwise.
char printable_or_dot(uint8_t byte);

// Dump out a sequence of bytes as hexadecimal and ASCII text.
void uart_dump_bytes(uart_t uart, const uint8_t buf[], size_t len);
