// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package axi_sram_env_pkg;
  import uvm_pkg::*;
  import axi_agent_pkg::*;

  `include "uvm_macros.svh"

  localparam int unsigned WordBytes = 8;   // AXI data width / 8
  localparam int unsigned CapBytes  = 16;  // CHERI capability (128-bit)

  `include "axi_sram_env_cfg.svh"
  `include "axi_sram_ref_model.svh"
  `include "axi_sram_env_cov.svh"
  `include "axi_sram_scoreboard.svh"
  `include "axi_sram_virtual_sequencer.svh"
  `include "axi_sram_env.svh"
endpackage : axi_sram_env_pkg
