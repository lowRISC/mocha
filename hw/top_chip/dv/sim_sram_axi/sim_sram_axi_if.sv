// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Intercepts an outbound AXI interface to instantiate an SRAM used for simulation only. It serves
// to capture CPU special communication with the DV environment. This interface purpose is for
// 'sw_test_status_if' and 'sw_logger_if', which are bound here in the TB top to capture SW test
// results and SW log messages.
interface sim_sram_axi_if (
  input logic clk_i,
  input logic rst_ni
);
  import top_pkg::*;

  // Control signals set by the Testbench
  logic [31:0] start_addr;
  logic [31:0] sw_dv_size;

  // Monitor signals driven by the Sink
  axi_req_t  req;
  axi_resp_t resp;

  // Logic to qualify a valid "Simulation Write"
  logic wr_valid;
  assign wr_valid = req.aw_valid && resp.aw_ready && req.w_valid && resp.w_ready;

endinterface : sim_sram_axi_if
