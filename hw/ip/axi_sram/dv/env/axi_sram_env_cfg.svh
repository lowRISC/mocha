// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Configuration of the axi_sram env, created and filled in by the test.
class axi_sram_env_cfg extends uvm_object;
  `uvm_object_utils(axi_sram_env_cfg)

  // The testbench clock and reset generator. Use it to apply a reset or wait for clocks.
  virtual clk_rst_if clk_rst_vif;

  // The SRAM's AXI port. Its u_clk_rst_if is the clock and reset the agent runs on.
  axi_vif_t axi_vif;

  // Build the scoreboard
  bit en_scb = 1'b1;

  // Build the coverage model when +en_cov is set
  bit en_cov;

  // Reads the sequences have completed. The scoreboard checks that it saw at least this many, so a
  // read that never reached it cannot pass unchecked.
  int unsigned min_checked_reads;

  // Drive the port with a manager agent and a virtual sequencer, or only observe it
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Standard SV/UVM methods
  extern function new(string name = "");
endclass : axi_sram_env_cfg


function axi_sram_env_cfg::new(string name = "");
  super.new(name);
endfunction : new
