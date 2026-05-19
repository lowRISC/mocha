// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This vseq is going to be starting a reactive sequence.
//
// i2c_monitor shares an analysis port with i2c_sequencer. It sends an i2c_item which contains
// a member "state". i2c_monitor watches the i2c_if and as soon as it sees the communication started
// on the bus, it change the state accordingly. Based on the state received on the
// analysis port of sequencer, i2c_base_seq initializes the start_item method to send i2c_item to
// i2c_driver so that it can drive ack, nack or rdata to the controller.
class top_chip_dv_i2c_host_tx_rx_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_i2c_host_tx_rx_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
endclass : top_chip_dv_i2c_host_tx_rx_vseq

function top_chip_dv_i2c_host_tx_rx_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_i2c_host_tx_rx_vseq::body();
  i2c_device_response_seq seq = i2c_device_response_seq::type_id::create("seq");

  // Configure the agent to be reactive
  cfg.m_i2c_agent_cfg.if_mode = Device;

  super.body();

  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);

  `uvm_info(`gfn, "Starting I2C Host TX-RX test", UVM_LOW)

  fork
    seq.start(p_sequencer.i2c_sqr);
  join_none
endtask : body
