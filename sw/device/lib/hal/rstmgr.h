// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/multibit.h"
#include <stdbool.h>
#include <stdint.h>

#define RSTMGR_ALERT_TEST_REG      (0x0)
#define RSTMGR_RESET_REQ_REG       (0x4)
#define RSTMGR_RESET_REQ_TRUE      (kMultiBitBool4True)
#define RSTMGR_RESET_INFO_REG      (0x8)
#define RSTMGR_RESET_INFO_POR      (0x1)
#define RSTMGR_RESET_INFO_LOW_PWR  (0x2)
#define RSTMGR_RESET_INFO_SW_RESET (0x4)

typedef void *rstmgr_t;

#define RSTMGR_FROM_BASE_ADDR(addr) ((rstmgr_t)(addr))

uint32_t rstmgr_reset_reason_get(rstmgr_t rstmgr);
void rstmgr_reset_reason_clear(rstmgr_t rstmgr, uint32_t reason);

void rstmgr_software_reset_request(rstmgr_t rstmgr);
bool rstmgr_software_reset_info_get(rstmgr_t rstmgr);
