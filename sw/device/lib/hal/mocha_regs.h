// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#define SYSCLK_FREQ (50000000)

#define DEV_WRITE(addr, val) (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr)       (*((volatile uint32_t *)(addr)))

#define UART_BASE (0x41000000)
