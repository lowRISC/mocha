// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

/* array length macro */
#define ARRAY_LEN(array) (sizeof(array) / sizeof((array)[0]))

/* inline assembly */
#define asm __asm__
