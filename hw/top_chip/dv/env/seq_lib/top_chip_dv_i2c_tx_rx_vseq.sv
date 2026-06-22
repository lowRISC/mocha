// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_i2c_tx_rx_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_i2c_tx_rx_vseq)

  // Below variables will get assigned through SW backdoor load. They are defined as byte size
  // arrays because "sw_symbol_backdoor_read/overwrite" takes an array as an argument to write or
  // read the SW symbol.
  //
  // Array of size 1 means that the SW symbol is byte size, size 2 means half word and so on.
  protected bit [7:0] sw_sys_clk_period_ns[1];
  protected bit [7:0] sw_scl_low_time_ns[2];
  protected bit [7:0] sw_scl_high_time_ns[2];
  protected bit [7:0] sw_data_setup_time_ns[2];
  protected bit [7:0] sw_data_hold_time_ns[2];
  protected bit [7:0] sw_setup_start_time_ns[2];
  protected bit [7:0] sw_hold_start_time_ns[2];
  protected bit [7:0] sw_setup_stop_time_ns[2];
  protected bit [7:0] sw_bus_free_time_ns[2];
  protected bit [7:0] sw_rise_time_ns[2];
  protected bit [7:0] sw_fall_time_ns[2];

  // The timing parameters in cycles used by the agent to add relevant delays before driving the
  // SCL and SDA.
  protected bit [15:0] scl_low_cycles;
  protected bit [15:0] scl_high_cycles;
  protected bit [15:0] sda_hold_cycles;
  protected bit [15:0] sda_setup_cycles;
  protected bit [15:0] start_setup_cycles;
  protected bit [15:0] start_hold_cycles;
  protected bit [15:0] stop_setup_cycles;
  protected bit [15:0] bus_free_cycles;
  protected bit [15:0] rise_cycles;
  protected bit [15:0] fall_cycles;

  // Number of bytes to read / write in a transfer. This will overwrite a SW symbol so that
  // the SW will read / write bytes based on xfer_bytes count
  protected rand bit [7:0] xfer_bytes[1];

  extern constraint xfer_bytes_c;

  extern function new(string name="");

  // Returns the ceiling of (a / b), converting a timing parameter "a" in nanoseconds to an integer
  // number of cycles by rounding up.
  extern protected function int unsigned round_up_divide(int unsigned a, int unsigned b);

  // Compute timing parameters utilized by the agent to add delays before driving SCL and SDA. The
  // calculations are taken from i2c_base_vseq.sv
  extern protected function void configure_agent_timing();
  extern protected function void print_i2c_timing_cfg();
endclass : top_chip_dv_i2c_tx_rx_vseq

// SW will perform a comparison check on each byte that was written and read. To do this accurately,
// the number of bytes should not exceed the depth of the TX / RX FIFO of the target and host,
// respectively.
constraint top_chip_dv_i2c_tx_rx_vseq::xfer_bytes_c {
  xfer_bytes[0] inside {[1 : FifoDepth]};
}

function top_chip_dv_i2c_tx_rx_vseq::new(string name = "");
  super.new(name);
endfunction

function int unsigned top_chip_dv_i2c_tx_rx_vseq::round_up_divide(int unsigned a, int unsigned b);
  return (((a - 1) / b) + 1);
endfunction

function void top_chip_dv_i2c_tx_rx_vseq::configure_agent_timing();
  // tHoldStart are the clk_i cycles to hold SDA low when SCL is high. Once SDA is low, the wait of
  // fall time and hold start time is required before pulling SCL low.
  cfg.m_i2c_agent_cfg.timing_cfg.tHoldStart = fall_cycles + start_hold_cycles;

  // Once i2c_if is done holding SDA low after the start condition, it pulls SCL low and waits for
  // tClockStart clk_i cycles before preparing to drive data on SDA.
  cfg.m_i2c_agent_cfg.timing_cfg.tClockStart = sda_hold_cycles;

  // tClockLow are the clk_i cycles delay before driving SDA. The SCL low period includes setup and
  // hold SDA times. The reason we subtract rise_cycles is that the later timing parameter
  // tSetupBit use it in order to hold SDA once it is driven.
  //
  // The explanation of +1 is given in i2c_base_vseq under get_timing_values().
  cfg.m_i2c_agent_cfg.timing_cfg.tClockLow = scl_low_cycles - (rise_cycles + sda_setup_cycles +
                                             sda_hold_cycles + 1);

  // tSetupBit are the clk_i cycles to hold the driven SDA during SCL low period.
  cfg.m_i2c_agent_cfg.timing_cfg.tSetupBit = rise_cycles + sda_setup_cycles;

  // For host, tClockPulse are the clk_i cycles to hold SCL high pulse. For Device, this is used as
  // a clock stretching delay.
  cfg.m_i2c_agent_cfg.timing_cfg.tClockPulse = rise_cycles + scl_high_cycles;

  // tHoldBit are the clk_i cycles to hold SDA once SCL goes low.
  cfg.m_i2c_agent_cfg.timing_cfg.tHoldBit = fall_cycles + sda_hold_cycles;

  // tClockStop are the clk_i cycles delay before driving the SCL pulse for stop condition. We don't
  // need to subtract any other parameter delay except sda_hold_cycles that was holding the N/Ack.
  cfg.m_i2c_agent_cfg.timing_cfg.tClockStop = (fall_cycles + scl_low_cycles) - sda_hold_cycles;

  // tSetupStop are the clk_i cycles delay before driving SDA high for stop condition.
  cfg.m_i2c_agent_cfg.timing_cfg.tSetupStop = rise_cycles + stop_setup_cycles;

  // tHoldStop are the clk_i cycles to hold the stop condition. Subtracts setup_start_cycles to initiate
  // the next start / restart timely.
  cfg.m_i2c_agent_cfg.timing_cfg.tHoldStop  = (rise_cycles + bus_free_cycles) - start_setup_cycles;
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
