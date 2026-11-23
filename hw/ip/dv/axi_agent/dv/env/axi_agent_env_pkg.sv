// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// AXI agent self-test package. Check agents directly against each other and against independent
// pulp_axi models, selected by +axi_link (see axi_agent_link_cfg and tb.sv).
package axi_agent_env_pkg;

  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import dv_lib_pkg::*;
  import axi_widths_pkg::*;
  import axi_agent_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // Keep the traffic window small so reads often check bytes written earlier
  parameter bit [31:0]   AxiWinBase  = 32'h1000_0000;
  parameter int unsigned AxiWinBytes = 32'h0001_0000;

  // The 4KB page that the subordinate agent answers with an error in the error test
  parameter bit [31:0] AgentErrPage = AxiWinBase + 32'hd000;

  // Half-size sim_mem window to promote reads of written bytes (unwritten bytes are random). The
  // top 4KB pages return SLVERR and DECERR.
  parameter int unsigned SimMemWinBytes   = 32'h0000_8000;
  parameter bit [31:0]   SimMemSlverrPage = AxiWinBase + 32'h6000;
  parameter bit [31:0]   SimMemDecerrPage = AxiWinBase + 32'h7000;

  // The axi_lite_regs block on the lite_regs link
  parameter bit [31:0]   LiteRegsBase  = AxiWinBase;
  parameter int unsigned LiteRegsBytes = 256;

  // Crossbar endpoint counts, subordinate window sizes from the bottom up, and manager ID width.
  // The remaining window has no route.
  parameter int unsigned XbarNumMgrs   = 2;
  parameter int unsigned XbarNumSubs   = 3;
  parameter int unsigned XbarSubBytes  = 32'h0000_5000;
  parameter int unsigned XbarMgrIdBits = 4;

  // Return zero-based beat n's address and byte lanes [lower, upper] using independent pulp_axi
  // burst equations. FIXED bursts reuse their first beat's lanes (AMBA AXI H.c A3.4.2), but
  // axi_pkg::beat_upper_byte gets later unaligned FIXED beats wrong.
  function automatic void beat_lanes(input  bit [AxiMaxAddrWidth-1:0] addr,
                                     input  bit [AxiSizeWidth-1:0]    size,
                                     input  bit [AxiLenWidth-1:0]     len,
                                     input  bit [AxiBurstWidth-1:0]   burst,
                                     input  int unsigned              bus_bytes,
                                     input  int unsigned              n,
                                     output bit [AxiMaxAddrWidth-1:0] beat_addr,
                                     output int unsigned              lower,
                                     output int unsigned              upper);
    int unsigned beat = (burst == axi_pkg::BURST_FIXED) ? 0 : n;

    beat_addr = axi_pkg::beat_addr(addr, size, len, burst, beat);
    lower     = axi_pkg::beat_lower_byte(addr, size, len, burst, bus_bytes, beat);
    upper     = axi_pkg::beat_upper_byte(addr, size, len, burst, bus_bytes, beat);
  endfunction : beat_lanes

  // The value that an unwritten mapped byte of an axi_agent_mapped_mem reads as
  function automatic bit [7:0] mapped_mem_default(bit [AxiMaxAddrWidth-1:0] addr);
    return addr[7:0] ^ addr[15:8] ^ 8'h5a;
  endfunction : mapped_mem_default

  typedef class axi_agent_env_cfg;
  typedef dv_base_env_cov #(.CFG_T(axi_agent_env_cfg)) axi_agent_env_cov;

  `include "axi_agent_mapped_mem.sv"
  `include "axi_agent_link_cfg.sv"
  `include "axi_agent_env_cfg.sv"
  `include "axi_agent_mgr_txn.sv"
  `include "axi_agent_bridge_burst.sv"
  `include "axi_agent_rand_req.sv"
  `include "axi_agent_reg_block.sv"
  `include "axi_agent_reg_ok_filter.sv"
  `include "axi_agent_virtual_sequencer.sv"
  `include "axi_agent_scoreboard.sv"
  `include "axi_agent_env.sv"
  `include "axi_agent_vseq_list.sv"

endpackage : axi_agent_env_pkg
