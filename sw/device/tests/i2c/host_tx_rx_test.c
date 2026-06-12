// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

// The const variables below are treated as symbols read by top_chip_dv_i2c_host_tx_rx_vseq in order
// to calculate agent timing parameters.
const uint8_t sys_clk_period_ns = SYSCLK_NS;

// The constants are the spec minimums for standard mode speed except hold_data_time_ns which should
// be at least one according to OpenTitan's programming guide.
const uint16_t scl_low_time_ns = 4700;
const uint16_t hold_data_time_ns = 1;

enum : uint8_t {
    device_addr = 0x3A,
    num_bytes = 0x8,
};

static bool write_transfer(i2c_t i2c, uint8_t addr, const uint8_t *data, uint8_t num_bytes)
{
    // Start a write transfer
    i2c_write_bytes(i2c, addr, data, num_bytes);
    return i2c_wait_transfer_finish(i2c);
}

static bool read_transfer(i2c_t i2c, uint8_t addr, uint8_t num_bytes)
{
    // Start a read transfer
    i2c_read_bytes(i2c, addr, num_bytes);
    return i2c_wait_transfer_finish(i2c);
}

static bool drive_transfer(i2c_t i2c, uint8_t addr, const uint8_t *data, uint8_t num_bytes)
{
    bool write_transfer_status = write_transfer(i2c, addr, data, num_bytes);
    bool read_transfer_status = read_transfer(i2c, addr, num_bytes);

    return (write_transfer_status && read_transfer_status);
}

static bool host_tx_rx_test(i2c_t i2c)
{
    // Data bytes to send to the target's receiver.
    uint8_t data_bytes[num_bytes];

    // Write walking 1's pattern
    for (uint8_t i = 0; i < num_bytes; i++) {
        data_bytes[i] = 1u << (i % 8);
    }

    if (!drive_transfer(i2c, device_addr, data_bytes, num_bytes)) {
        return false;
    }

    for (uint8_t i = 0; i < num_bytes; i++) {
        if (data_bytes[i] != i2c_rdata_byte(i2c)) {
            return false;
        }
    }

    return true;
}

bool test_main()
{
    i2c_t i2c = mocha_system_i2c();
    i2c_init(i2c, i2c_speed_mode_standard);
    i2c_enable_controller_mode(i2c);
    return host_tx_rx_test(i2c);
}
