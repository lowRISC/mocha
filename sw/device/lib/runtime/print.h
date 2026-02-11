// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/uart.h"
#include <stddef.h>

[[gnu::format(printf, 2, 3)]] size_t uprintf(uart_t uart, const char *format, ...);
[[gnu::format(printf, 3, 4)]] size_t snprintf(char *ptr, size_t len, const char *format, ...);
