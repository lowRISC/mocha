// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// UVM test package for axi_sram. Each block lives in its own file and is
// `included here in dependency order:
//
//   axi_sram_ref_model.svh          -- behavioural data + CHERI-tag shadow
//   axi_sram_scoreboard.svh         -- checks the DUT vs the reference model
//   axi_sram_virtual_sequencer.svh  -- hub of AXI channel sequencers + clk_rst vif
//   axi_sram_env.svh                -- wraps the agent and scoreboard
//   seq_lib/axi_sram_vseq_list.sv   -- base vseq + one vseq per vplan item
//   axi_sram_base_test.svh          -- builds the env, runs +UVM_TEST_SEQ

package axi_sram_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;

  // SRAM geometry. The size comes from the address map, so there is one source for it.
  localparam longint unsigned SramSize     = top_pkg::SRAMLength;
  localparam int unsigned     WordBytes    = 8;                // AXI data width / 8
  localparam int unsigned     CapBytes     = 16;               // CHERI capability (128-bit)
  localparam bit [63:0]       LastWordAddr = SramSize - WordBytes;  // 0x1FFF8
  localparam bit [63:0]       LastCapAddr  = SramSize - CapBytes;   // 0x1FFF0

  // Components and sequences, in dependency order.
  `include "axi_sram_ref_model.svh"
  `include "axi_sram_scoreboard.svh"
  `include "axi_sram_virtual_sequencer.svh"
  `include "axi_sram_env.svh"
  `include "axi_sram_vseq_list.sv"
  `include "axi_sram_base_test.svh"
endpackage
