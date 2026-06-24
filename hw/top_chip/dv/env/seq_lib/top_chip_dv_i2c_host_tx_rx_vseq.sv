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

  // Declare the device_addr as a byte size array because sw_symbol_backdoor_overwrite() expects the
  // data that is going to overwrite the SW symbol to be an array
  local rand bit [7:0] device_addr[1];

  extern function new(string name="");
  extern virtual task dut_init(string reset_kind = "HARD");
  extern task body();
endclass : top_chip_dv_i2c_host_tx_rx_vseq

function top_chip_dv_i2c_host_tx_rx_vseq::new(string name = "");
  super.new(name);
endfunction

task top_chip_dv_i2c_host_tx_rx_vseq::dut_init(string reset_kind = "HARD");
  super.dut_init(reset_kind);

  // Read the timing parameters through SW backdoor load
  sw_symbol_backdoor_read("sys_clk_period_ns", sw_sys_clk_period_ns);
  sw_symbol_backdoor_read("scl_low_time_ns", sw_scl_low_time_ns);
  sw_symbol_backdoor_read("hold_data_time_ns", sw_data_hold_time_ns);

  // Overwrite the SW symbol with the randomized value
  sw_symbol_backdoor_overwrite("byte_count", xfer_bytes);
  sw_symbol_backdoor_overwrite("device_addr", device_addr);

  scl_low_cycles    = round_up_divide({sw_scl_low_time_ns[1], sw_scl_low_time_ns[0]},
                                      sw_sys_clk_period_ns[0]);
  sda_hold_cycles   = round_up_divide({sw_data_hold_time_ns[1], sw_data_hold_time_ns[0]},
                                      sw_sys_clk_period_ns[0]);

endtask

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
