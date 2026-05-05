// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

// Read temperature from an AS6212 sensor (default address 0x48)
static bool as6212_test(i2c_t i2c)
{
    // Write the desired register index
    if (!i2c_write_byte(i2c, 0x48u, 0u)) {
        return false;
    }
    // Read current temperature
    uint8_t byte = i2c_read_byte(i2c, 0x48u);
    if (byte == 0xFFu /* error value */) {
        return false;
    }
    int16_t tval = byte; // signed, as temperature can be negative
    tval <<= 8; // first byte is the most-significant byte of two
    tval >>= 7; // convert from units of 1/128 degC to 1 degC
    return (5 <= tval && tval <= 45); // check temperature is realistic
}

bool test_main()
{
    i2c_t i2c = mocha_system_i2c();
    i2c_init(i2c);

    // -- Configure IP for Controller mode --
    DEV_WRITE(i2c + I2C_CTRL_REG, (1u << I2C_CTRL_ENABLEHOST));
    return as6212_test(i2c);
}
