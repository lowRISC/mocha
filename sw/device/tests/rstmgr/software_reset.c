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

    if (rstmgr_software_reset_info_get(rstmgr)) {
        return true;
    }
    // Request a reset of the system.
    rstmgr_software_reset_request(rstmgr);

    // Must wait here for reset to happen.
    while (1) {
    }
    return false;
}
