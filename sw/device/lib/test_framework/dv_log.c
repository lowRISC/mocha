// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "test_framework/dv_log.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdarg.h>

void dv_log_write(const log_fields_t *log, ...)
{
    dv_window_t dv_window = mocha_system_dv_window();
    VOLATILE_WRITE(dv_window->log, (uint32_t)(uintptr_t)log);

    va_list args;
    va_start(args, log);
    for (uint32_t i = 0; i < log->nargs; i++) {
        VOLATILE_WRITE(dv_window->log, va_arg(args, uint32_t));
    }
    va_end(args);
}
