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
    i2c_write_byte(i2c, 0x48u, 0u);

    // Check if the write was successful
    if (!check_wr_xfer_status(i2c)) {
        return false;
    }

    // Read current temperature
    i2c_read_byte(i2c, 0x48u);

    // Check if the read was successful
    if (!check_rd_xfer_status(i2c)) {
        return false;
    }

    // If the read was successful, then retrieve the data from the fifo.
    uint8_t byte = DEV_READ(i2c + I2C_RDATA_REG);

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
    enable_controller_mode(i2c);
    return as6212_test(i2c);
}
