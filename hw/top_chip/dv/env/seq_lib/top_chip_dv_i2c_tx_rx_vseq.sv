// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_i2c_tx_rx_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_i2c_tx_rx_vseq)

  // Below variables will get assigned through SW backdoor load. They are defined as byte size
  // arrays because "sw_symbol_backdoor_read/overwrite" takes an array as an argument to write or
  // read the SW symbol.
  protected bit [7:0] sw_sys_clk_period_ns[1];
  protected bit [7:0] sw_scl_low_time_ns[2];
  protected bit [7:0] sw_data_hold_time_ns[2];

  // The timing parameters in cycles used by the agent to add relevant delays before driving the
  // responses.
  protected bit [15:0] scl_low_cycles;
  protected bit [15:0] sda_hold_cycles;

  extern function new(string name="");

  // Returns the ceiling of (a / b), converting a timing parameter "a" in nanoseconds to an integer
  // number of cycles by rounding up.
  extern protected function int unsigned round_up_divide(int unsigned a, int unsigned b);

  // Compute timing parameters utilized by the agent to add delays to the responses
  extern protected function void configure_agent_timing();
  extern protected function void print_i2c_timing_cfg();
endclass : top_chip_dv_i2c_tx_rx_vseq

function top_chip_dv_i2c_tx_rx_vseq::new(string name = "");
  super.new(name);
endfunction

function int unsigned top_chip_dv_i2c_tx_rx_vseq::round_up_divide(int unsigned a, int unsigned b);
  return (((a - 1) / b) + 1);
endfunction

function void top_chip_dv_i2c_tx_rx_vseq::configure_agent_timing();
  // tSetupBit are the clk_i cycles before SCL goes high to drive SDA. Agent should drive SDA at
  // least two cycles before SCL goes high.
  int unsigned tSetupBit = 2;
  cfg.m_i2c_agent_cfg.timing_cfg.tSetupBit = tSetupBit;

  // tHoldBit are the clk_i cycles to hold SDA after SCL goes low.
  cfg.m_i2c_agent_cfg.timing_cfg.tHoldBit = sda_hold_cycles;

  // Used by i2c_if to stretch SCL by the amount of tClockpulse clk_i cycles before driving SDA. If
  // tClockPulse is greater than the clk_i cycles taken by an SCL pulse, then i2c_monitor
  // acknowledges the "ack" late and then drives Rdata on SDA when SCL is high.
  cfg.m_i2c_agent_cfg.timing_cfg.tClockPulse = scl_low_cycles;

  // tClockLow are the clk_i cycles that the i2c_driver use before driving SDA after stretching SCL
  // by tClockPulse clk_i cycles. Drive SDA at least tSetupBit cycles earlier to avoid the chances
  // of SDA interference.
  cfg.m_i2c_agent_cfg.timing_cfg.tClockLow = scl_low_cycles - tSetupBit;
endfunction

function void top_chip_dv_i2c_tx_rx_vseq::print_i2c_timing_cfg();
  timing_cfg_t timing_cfg = cfg.m_i2c_agent_cfg.timing_cfg;
  string str = "";

  // Print the timing parameters in a tabular form
  str = {str, "\n+----------------------+---------+"};
  str = {str, $sformatf("\n| %-20s | %-7s |", "Timing Parameter", "Value")};
  str = {str, "\n+----------------------+---------+"};
  str = {str, $sformatf("\n| %-20s | %7d |", "tSetupStart", timing_cfg.tSetupStart)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tHoldStart", timing_cfg.tHoldStart)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tClockStart", timing_cfg.tClockStart)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tClockLow", timing_cfg.tClockLow)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tSetupBit", timing_cfg.tSetupBit)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tClockPulse", timing_cfg.tClockPulse)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tHoldBit", timing_cfg.tHoldBit)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tClockStop", timing_cfg.tClockStop)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tSetupStop", timing_cfg.tSetupStop)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tHoldStop", timing_cfg.tHoldStop)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tTimeOut", timing_cfg.tTimeOut)};
  str = {str, $sformatf("\n| %-20s | %7d |", "enbTimeOut", timing_cfg.enbTimeOut)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tStretchHostClock",timing_cfg.tStretchHostClock)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tSdaUnstable", timing_cfg.tSdaUnstable)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tSdaInterference", timing_cfg.tSdaInterference)};
  str = {str, $sformatf("\n| %-20s | %7d |", "tSclInterference", timing_cfg.tSclInterference)};
  `uvm_info(`gfn, $sformatf("%s", str), UVM_MEDIUM);
endfunction
