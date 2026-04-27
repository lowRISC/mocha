// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/pwrmgr.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

static bool control_test(pwrmgr_t pwrmgr)
{
    uint32_t initial = pwrmgr_control_get(pwrmgr);
    uint32_t expected_reset = PWRMGR_CONTROL_MAIN_PD_N_BIT;
    if ((initial & PWRMGR_CONTROL_MASK) != expected_reset) {
        return false;
    }

    uint32_t updated = PWRMGR_CONTROL_LOW_POWER_HINT_BIT | PWRMGR_CONTROL_CORE_CLK_EN_BIT |
                       PWRMGR_CONTROL_IO_CLK_EN_BIT;

    pwrmgr_control_set(pwrmgr, updated);
    pwrmgr_cfg_sync(pwrmgr);
    if ((pwrmgr_control_get(pwrmgr) & PWRMGR_CONTROL_MASK) != updated) {
        return false;
    }

    pwrmgr_control_set(pwrmgr, initial);
    pwrmgr_cfg_sync(pwrmgr);
    return (pwrmgr_control_get(pwrmgr) & PWRMGR_CONTROL_MASK) == expected_reset;
}

static bool wakeup_enable_test(pwrmgr_t pwrmgr)
{
    if (pwrmgr_wakeup_enable_get(pwrmgr) != 0u) {
        return false;
    }

    pwrmgr_wakeup_enable_set(pwrmgr, PWRMGR_WAKEUP_EN_SOC_PROXY_EXT_WKUP_REQ_BIT);
    pwrmgr_cfg_sync(pwrmgr);
    if (pwrmgr_wakeup_enable_get(pwrmgr) != PWRMGR_WAKEUP_EN_SOC_PROXY_EXT_WKUP_REQ_BIT) {
        return false;
    }

    pwrmgr_wakeup_enable_set(pwrmgr, 0u);
    pwrmgr_cfg_sync(pwrmgr);
    return pwrmgr_wakeup_enable_get(pwrmgr) == 0u;
}

static bool status_test(pwrmgr_t pwrmgr)
{
    if (pwrmgr_wakeup_status_get(pwrmgr) != 0u) {
        return false;
    }
    if (pwrmgr_reset_status_get(pwrmgr) != 0u) {
        return false;
    }
    if (pwrmgr_escalate_reset_status_get(pwrmgr) != 0u) {
        return false;
    }
    if (pwrmgr_wake_info_get(pwrmgr) != 0u) {
        return false;
    }

    pwrmgr_wake_info_clear(pwrmgr,
                           PWRMGR_WAKE_INFO_REASONS_BIT | PWRMGR_WAKE_INFO_FALL_THROUGH_BIT |
                               PWRMGR_WAKE_INFO_ABORT_BIT);
    return pwrmgr_wake_info_get(pwrmgr) == 0u;
}

bool test_main()
{
    pwrmgr_t pwrmgr = mocha_system_pwrmgr();
    return control_test(pwrmgr) && wakeup_enable_test(pwrmgr) && status_test(pwrmgr);
}
