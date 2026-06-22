// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This file is supposed to be shared between different tests. It contains test specific
// parameters that will be read and over-write by top_chip_dv_i2c_tx_rx_vseq.

#include "hal/mocha.h"

#define TX_FIFO_DEPTH (64)

// The const variables below are treated as symbols read by top_chip_dv_i2c_tx_rx_vseq in order
// to calculate agent timing parameters.
const uint8_t sys_clk_period_ns = SYSCLK_NS;

// The constants assigned below are the spec minimums for standard mode speed except
// hold_data_time_ns which should be at least one according to OpenTitan's programming guide.
const uint16_t scl_period_time_ns = 10000;
const uint16_t scl_low_time_ns = 4700;
const uint16_t scl_high_time_ns = 4000;
const uint16_t hold_data_time_ns = 1;
const uint16_t setup_data_time_ns = 250;
const uint16_t setup_start_time_ns = 4700;
const uint16_t hold_start_time_ns = 4000;
const uint16_t setup_stop_time_ns = 4000;
const uint16_t bus_free_time_ns = 4700;
const uint16_t rise_time_ns = I2C_RISE_NS;
const uint16_t fall_time_ns = I2C_FALL_NS;

// The symbols below are going to be overwritten through sw_symbol_backdoor_overwrite() in
// top_chip_dv_i2c_tx_rx_vseq.sv
volatile const uint8_t device_addr = 0x0;
volatile const uint8_t byte_count = TX_FIFO_DEPTH;
