// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

bool test_main()
{
    i2c_t i2c = mocha_system_i2c();
    i2c_init(i2c);
    // Queue write request
    DEV_WRITE(i2c + I2C_FDATA_REG,
              ((1u << I2C_FDATA_START) | (((0xAAu << 1) | 0u) << I2C_FDATA_FBYTE)));
    DEV_WRITE(i2c + I2C_FDATA_REG, ((1u << I2C_FDATA_STOP) | (0x43u << I2C_FDATA_FBYTE)));

    return true;
}
