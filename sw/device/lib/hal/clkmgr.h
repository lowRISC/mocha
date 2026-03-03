// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include <stdbool.h>
#include <stdint.h>

#define CLKMGR_ALERT_TEST_REG  (0x00)
#define CLKMGR_CLK_ENABLES_REG (0x18)
#define CLKMGR_CLK_ENABLES_ALL (1)

typedef void *clkmgr_t;

#define CLKMGR_FROM_BASE_ADDR(addr) ((clkmgr_t)(addr))
