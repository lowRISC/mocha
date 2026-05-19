// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

static bool i2c_host_wr_xfer(i2c_t i2c, uint8_t addr, const uint8_t *data, uint8_t num_wr_bytes)
{
    // Start a write transfer
    i2c_write_n_bytes(i2c, addr, data, num_wr_bytes);
    return wait_wr_xfer_status(i2c);
}

static bool i2c_host_rd_xfer(i2c_t i2c, uint8_t addr, uint8_t num_rd_bytes)
{
    // Start a read transfer
    i2c_read_n_bytes(i2c, addr, num_rd_bytes);
    return wait_rd_xfer_status(i2c);
}

static bool host_rx_tx_test(i2c_t i2c, uint8_t addr, const uint8_t *data, uint8_t num_bytes)
{
    bool rd_xfer_status, wr_xfer_status;

    wr_xfer_status = i2c_host_wr_xfer(i2c, addr, data, num_bytes);
    rd_xfer_status = i2c_host_rd_xfer(i2c, addr, num_bytes);

    return (wr_xfer_status && rd_xfer_status);
}

bool test_main()
{
    // Data bytes to send to the target's receiver
    uint8_t wr_data_bytes[8];

    // Return status of the test
    bool success = false;

    i2c_t i2c = mocha_system_i2c();
    i2c_init(i2c, standard_mode);

    // -- Configure IP for Controller mode --
    enable_controller_mode(i2c);

    // Write walking 1's pattern
    for (uint8_t i = 0; i < (uint8_t)(sizeof(wr_data_bytes)); i++) {
        wr_data_bytes[i] = 1u << i;
    }

    if (host_rx_tx_test(i2c, 0x48u, wr_data_bytes, sizeof(wr_data_bytes))) {
        uint8_t rd_data_bytes[sizeof(wr_data_bytes)];
        for (uint8_t i = 0; i < (uint8_t)(sizeof(rd_data_bytes)); i++) {
            rd_data_bytes[i] = i2c_rdata_byte(i2c);
            if (wr_data_bytes[i] != rd_data_bytes[i]) {
                return false;
            }
        }
        success = true;
    }

    return success;
}
