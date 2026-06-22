// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/i2c.h"
#include "hal/mmio.h"
#include "hal/mocha.h"
#include <stdbool.h>
#include <stdint.h>

#define TX_FIFO_DEPTH (64)

// The const variables below are treated as symbols read by top_chip_dv_i2c_host_tx_rx_vseq in order
// to calculate agent timing parameters.
const uint8_t sys_clk_period_ns = SYSCLK_NS;

// The constants assigned below are the spec minimums for standard mode speed except
// hold_data_time_ns which should be at least one according to OpenTitan's programming guide.
const uint16_t scl_low_time_ns = 4700;
const uint16_t scl_high_time_ns = 4000;
const uint16_t hold_data_time_ns = 1;
const uint16_t setup_data_time_ns = 250;
const uint16_t setup_start_time_ns = 4700;
const uint16_t hold_start_time_ns = 4000;
const uint16_t setup_stop_time_ns = 4000;
const uint16_t hold_stop_time_ns = 4700;
const uint16_t rise_time_ns = I2C_RISE_NS;
const uint16_t fall_time_ns = I2C_FALL_NS;
const uint8_t device_mask0 = 0x7F;
const uint8_t device_mask1 = 0x7F;

// The symbols below are going to be overwritten through sw_symbol_backdoor_overwrite() in
// top_chip_dv_i2c_device_tx_rx_vseq.sv
volatile const uint8_t device_addr0 = 0x0;
volatile const uint8_t device_addr1 = 0x0;
volatile const uint8_t byte_count = TX_FIFO_DEPTH;
volatile uint8_t tx_fifo_wr_done = 0x0;

static bool check_num_bytes()
{
    return ((byte_count > 0) && (byte_count <= TX_FIFO_DEPTH));
}

// Wait for the read transfer to complete by checking interrupt state and status register fields.
static bool wait_read_finish(i2c_t i2c)
{
    while (true) {
        if (i2c_read_intr_state(i2c) & i2c_intr_cmd_complete) {
            // If the SW is here, then transfer is terminated with an `stop`. Check if every byte in
            // TX FIFO was sent to the host.
            if (!(i2c_read_status(i2c) & i2c_status_txempty)) {
                return false;
            }
            return true;
        }
    }
}

static bool drain_acq_fifo(i2c_t i2c)
{
    return (i2c_target_drain_start_sig_acq_data(i2c) && i2c_target_drain_end_sig_acq_data(i2c));
}

static bool read_transfer_done(i2c_t i2c)
{
    // Wait until host done reading all the bytes in TX FIFO
    if (!wait_read_finish(i2c)) {
        return false;
    }

    // Drain the ACQ FIFO so that the comparison between read / write bytes can perform accurately
    if (!drain_acq_fifo(i2c)) {
        return false;
    }

    return true;
}

static bool write_transfer_done(i2c_t i2c)
{
    // Wait for the write transfer to complete by checking interrupt state.
    while (true) {
        if (i2c_read_intr_state(i2c) & i2c_intr_cmd_complete) {
            // Drop the address, direction and start signal entry
            if (!i2c_target_drain_start_sig_acq_data(i2c)) {
                return false;
            }
            return true;
        }
    }
}

static bool compare_read_write_bytes(i2c_t i2c, uint8_t num_bytes, const uint8_t *data)
{
    for (uint8_t i = 0; i < num_bytes; i++) {
        i2c_acqdata acq_data = i2c_read_acqdata(i2c);

        // The data byte contained in the ACQ FIFO should have the signal stored as "none"
        if ((data[i] != acq_data.abyte) || (acq_data.signal != none)) {
            return false;
        }
    }

    return true;
}

static bool device_tx_rx_test(i2c_t i2c)
{
    uint8_t data_bytes[byte_count];

    if (!check_num_bytes()) {
        return false;
    }

    // Set the target addresses. Both address masks are set as 0x7F to match every bit of
    // device_addr0 and device_addr1. Now, if the host sends the address that matches with either of
    // the two addresses then the I2C target will respond to that byte.
    i2c_set_target_id(i2c, device_addr0, device_mask0, device_addr1, device_mask1);

    // Write walking 1's pattern
    for (uint8_t i = 0; i < byte_count; i++) {
        data_bytes[i] = 1u << (i % 8);
        i2c_write_tx_data(i2c, data_bytes[i]);
    }

    // top_chip_i2c_device_tx_rx_vseq will wait before driving the transfer for this SW symbol.
    // Otherwise, SW and Vseq will be out of sync i.e. Vseq drives a start condition when SW is in
    // the middle of configuring the I2C target registers.
    tx_fifo_wr_done = 0x1u;

    if (!read_transfer_done(i2c)) {
        return false;
    }

    // Clear the cmd_complete interrupt state
    i2c_clear_cmd_complete(i2c);

    if (!write_transfer_done(i2c)) {
        return false;
    }

    if (!compare_read_write_bytes(i2c, byte_count, data_bytes)) {
        return false;
    }

    return true;
}

bool test_main()
{
    i2c_t i2c = mocha_system_i2c();
    i2c_init(i2c, i2c_speed_mode_standard);
    i2c_enable_target_mode(i2c);
    return device_tx_rx_test(i2c);
}
