// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Virtual sequence for testing the DUT as an I2C host/controller.
//
// The agent is configured in Device mode, acting as a reactive target that responds to transactions
// initiated by the DUT. The i2c_monitor watches the bus and forwards observed items to the
// i2c_sequencer via an analysis port. The i2c_device_response_seq then creates ACK/NACK/Rdata
// responses and i2c_driver drives them back to the DUT in response.
class top_chip_dv_i2c_host_tx_rx_vseq extends top_chip_dv_i2c_tx_rx_vseq;
  `uvm_object_utils(top_chip_dv_i2c_host_tx_rx_vseq)

  extern function new(string name="");
  extern task body();
endclass : top_chip_dv_i2c_host_tx_rx_vseq

function top_chip_dv_i2c_host_tx_rx_vseq::new(string name = "");
  super.new(name);
endfunction

task top_chip_dv_i2c_host_tx_rx_vseq::body();
  i2c_device_response_seq seq = i2c_device_response_seq::type_id::create("seq");

  // Configure the agent to be reactive
  cfg.m_i2c_agent_cfg.if_mode = Device;
  super.body();

  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);
  `uvm_info(`gfn, "Starting I2C Host TX-RX test", UVM_LOW)

  configure_agent_timing();
  print_i2c_timing_cfg();

  fork
    seq.start(p_sequencer.i2c_sqr);
  join_none
endtask
