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
    uint8_t w_data = 0;

    // Write the desired register index
    i2c_write_bytes(i2c, 0x48u, &w_data, 1);

    // Check if the write was successful
    if (!i2c_wait_write_finish(i2c)) {
        return false;
    }

    // Read current temperature
    i2c_read_bytes(i2c, 0x48u, 1);

    // Check if the read was successful
    if (!i2c_wait_read_finish(i2c)) {
        return false;
    }

    // If the read was successful, then retrieve the data from the fifo.
    uint8_t byte = i2c_rdata_byte(i2c);

    int16_t tval = byte; // signed, as temperature can be negative
    tval <<= 8; // first byte is the most-significant byte of two
    tval >>= 7; // convert from units of 1/128 degC to 1 degC
    return (5 <= tval && tval <= 45); // check temperature is realistic
}

bool test_main()
{
    i2c_t i2c = mocha_system_i2c();
    i2c_init(i2c, i2c_speed_mode_standard);

    // -- Configure IP for Controller mode --
    i2c_enable_controller_mode(i2c);
    return as6212_test(i2c);
}
