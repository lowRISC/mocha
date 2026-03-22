// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/rstmgr.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdint.h>

void rstmgr_software_reset_request(rstmgr_t rstmgr)
{
    DEV_WRITE(rstmgr + RSTMGR_RESET_REQ_REG, RSTMGR_RESET_REQ_TRUE);
}

bool rstmgr_software_reset_info_get(rstmgr_t rstmgr)
{
    if (DEV_READ(rstmgr + RSTMGR_RESET_INFO_REG) & RSTMGR_RESET_INFO_SW_RESET) {
        // Clear the info bit before returning.
        DEV_WRITE(rstmgr + RSTMGR_RESET_INFO_REG, RSTMGR_RESET_INFO_SW_RESET);
        return true;
    }
    return false;
}
