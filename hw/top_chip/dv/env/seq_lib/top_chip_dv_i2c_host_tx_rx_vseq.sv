// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

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
  super.body();
  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);

  `uvm_info(`gfn, "Starting I2C Host TX-RX test", UVM_LOW)
  seq.start(p_sequencer.i2c_sqr);
endtask : body
