// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/rstmgr.h"
#include <stdbool.h>
#include <stdint.h>

bool test_main()
{
    rstmgr_t rstmgr = mocha_system_rstmgr();
    uint32_t reason = rstmgr_reset_reason_get(rstmgr);

    if (reason & RSTMGR_RESET_INFO_POR) {
        rstmgr_reset_reason_clear(rstmgr, RSTMGR_RESET_INFO_POR);
        rstmgr_software_reset_request(rstmgr);

        // Must wait here for reset to happen.
        while (1) {
        }
    }

    if (reason & RSTMGR_RESET_INFO_SW_RESET) {
        rstmgr_reset_reason_clear(rstmgr, RSTMGR_RESET_INFO_SW_RESET);
        return true;
    }

    return false;
}
