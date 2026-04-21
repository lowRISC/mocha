// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/pwrmgr.h"
#include "hal/mmio.h"
#include <stdint.h>

static uint32_t pwrmgr_read(pwrmgr_t pwrmgr, uintptr_t reg)
{
    return DEV_READ(pwrmgr + reg);
}

static void pwrmgr_write(pwrmgr_t pwrmgr, uintptr_t reg, uint32_t value)
{
    DEV_WRITE(pwrmgr + reg, value);
}

uint32_t pwrmgr_control_get(pwrmgr_t pwrmgr)
{
    return pwrmgr_read(pwrmgr, PWRMGR_CONTROL_REG);
}

void pwrmgr_control_set(pwrmgr_t pwrmgr, uint32_t value)
{
    pwrmgr_write(pwrmgr, PWRMGR_CONTROL_REG, value & PWRMGR_CONTROL_MASK);
}

void pwrmgr_cfg_sync(pwrmgr_t pwrmgr)
{
    pwrmgr_write(pwrmgr, PWRMGR_CFG_CDC_SYNC_REG, 1u);
    while ((pwrmgr_read(pwrmgr, PWRMGR_CFG_CDC_SYNC_REG) & 1u) != 0u) {
    }
}

uint32_t pwrmgr_wakeup_enable_get(pwrmgr_t pwrmgr)
{
    return pwrmgr_read(pwrmgr, PWRMGR_WAKEUP_EN_REG);
}

void pwrmgr_wakeup_enable_set(pwrmgr_t pwrmgr, uint32_t value)
{
    pwrmgr_write(pwrmgr, PWRMGR_WAKEUP_EN_REG, value);
}

uint32_t pwrmgr_wakeup_status_get(pwrmgr_t pwrmgr)
{
    return pwrmgr_read(pwrmgr, PWRMGR_WAKE_STATUS_REG);
}

uint32_t pwrmgr_reset_status_get(pwrmgr_t pwrmgr)
{
    return pwrmgr_read(pwrmgr, PWRMGR_RESET_STATUS_REG);
}

uint32_t pwrmgr_escalate_reset_status_get(pwrmgr_t pwrmgr)
{
    return pwrmgr_read(pwrmgr, PWRMGR_ESCALATE_RESET_STATUS_REG);
}

uint32_t pwrmgr_wake_info_get(pwrmgr_t pwrmgr)
{
    return pwrmgr_read(pwrmgr, PWRMGR_WAKE_INFO_REG);
}

void pwrmgr_wake_info_clear(pwrmgr_t pwrmgr, uint32_t mask)
{
    pwrmgr_write(pwrmgr, PWRMGR_WAKE_INFO_REG, mask);
}
