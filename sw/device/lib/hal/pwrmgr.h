// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Power manager interface.

#pragma once

#include <stdint.h>

#define PWRMGR_CONTROL_REG               (0x14)
#define PWRMGR_CFG_CDC_SYNC_REG          (0x18)
#define PWRMGR_WAKEUP_EN_REG             (0x20)
#define PWRMGR_WAKE_STATUS_REG           (0x24)
#define PWRMGR_RESET_STATUS_REG          (0x30)
#define PWRMGR_ESCALATE_RESET_STATUS_REG (0x34)
#define PWRMGR_WAKE_INFO_REG             (0x3C)

#define PWRMGR_CONTROL_LOW_POWER_HINT_BIT (1u << 0)
#define PWRMGR_CONTROL_CORE_CLK_EN_BIT    (1u << 4)
#define PWRMGR_CONTROL_IO_CLK_EN_BIT      (1u << 5)
#define PWRMGR_CONTROL_MAIN_PD_N_BIT      (1u << 6)
#define PWRMGR_CONTROL_MASK \
    (PWRMGR_CONTROL_LOW_POWER_HINT_BIT | PWRMGR_CONTROL_CORE_CLK_EN_BIT | \
     PWRMGR_CONTROL_IO_CLK_EN_BIT | PWRMGR_CONTROL_MAIN_PD_N_BIT)

#define PWRMGR_WAKEUP_EN_SOC_PROXY_EXT_WKUP_REQ_BIT (1u << 0)

#define PWRMGR_WAKE_INFO_REASONS_BIT      (1u << 0)
#define PWRMGR_WAKE_INFO_FALL_THROUGH_BIT (1u << 1)
#define PWRMGR_WAKE_INFO_ABORT_BIT        (1u << 2)

typedef void *pwrmgr_t;

#define PWRMGR_FROM_BASE_ADDR(addr) ((pwrmgr_t)(addr))

uint32_t pwrmgr_control_get(pwrmgr_t pwrmgr);
void pwrmgr_control_set(pwrmgr_t pwrmgr, uint32_t value);

void pwrmgr_cfg_sync(pwrmgr_t pwrmgr);

uint32_t pwrmgr_wakeup_enable_get(pwrmgr_t pwrmgr);
void pwrmgr_wakeup_enable_set(pwrmgr_t pwrmgr, uint32_t value);

uint32_t pwrmgr_wakeup_status_get(pwrmgr_t pwrmgr);
uint32_t pwrmgr_reset_status_get(pwrmgr_t pwrmgr);
uint32_t pwrmgr_escalate_reset_status_get(pwrmgr_t pwrmgr);

uint32_t pwrmgr_wake_info_get(pwrmgr_t pwrmgr);
void pwrmgr_wake_info_clear(pwrmgr_t pwrmgr, uint32_t mask);
