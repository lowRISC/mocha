// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module mem_downsizer (
  // Clocking and reset
  input  logic clk_i,
  input  logic rst_ni,

  // 64-bit memory request in
  input  logic                                 mem64_req_i,
  output logic                                 mem64_gnt_o,
  input  logic                                 mem64_we_i,
  input  logic [(top_pkg::AxiDataWidth/8)-1:0] mem64_be_i,
  input  logic [top_pkg::AxiAddrWidth-1:0]     mem64_addr_i,
  input  logic [top_pkg::AxiDataWidth-1:0]     mem64_wdata_i,
  output logic                                 mem64_rvalid_o,
  output logic [top_pkg::AxiDataWidth-1:0]     mem64_rdata_o,

  // 32-bit memory request out
  output logic                          mem32_req_o,
  input  logic                          mem32_gnt_i,
  output logic                          mem32_we_o,
  output logic [(top_pkg::TL_DW/8)-1:0] mem32_be_o,
  output logic [top_pkg::TL_AW-1:0]     mem32_addr_o,
  output logic [top_pkg::TL_DW-1:0]     mem32_wdata_o,
  input  logic                          mem32_rvalid_i,
  input  logic [top_pkg::TL_DW-1:0]     mem32_rdata_i
);
  // Send side downsizer signals
  logic                                 dw_valid;     // Has valid transaction
  logic                                 dw_first_done;
  logic            [top_pkg::TL_AW-1:0] dw_store_addr;
  logic     [top_pkg::AxiDataWidth-1:0] dw_store_wdata;
  logic                                 dw_store_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] dw_store_be;

  // Receive side upsizer signals
  logic        uw_valid;        // Has valid transaction
  logic [31:0] uw_first32_rdata;

  // Send side downsizer
  assign mem64_gnt_o = dw_valid; // Grant when empty, otherwise process existing transaction

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dw_valid      <= 0;
      dw_first_done <= 0;

      mem32_req_o   <= 0; // No req when empty
      mem32_we_o    <= '0;
      mem32_be_o    <= '0;
      mem32_addr_o  <= '0;
      mem32_wdata_o <= '0;
    end else if (!dw_valid && mem64_req_i) begin // New request
      dw_valid      <= 1;
      dw_first_done <= 0; // have not done first 32 bits

      // Store transaction information
      dw_store_addr  <= mem64_addr_i[top_pkg::TL_AW-1:0];
      dw_store_wdata <= mem64_wdata_i;
      dw_store_we    <= mem64_we_i;
      dw_store_be    <= mem64_be_i;

      mem32_req_o   <= 0;
      mem32_we_o    <= '0;
      mem32_be_o    <= '0;
      mem32_addr_o  <= '0;
      mem32_wdata_o <= '0;
    end else if (dw_valid && !mem32_req_o && !dw_first_done) begin // Valid transaction, no untaken output, but have not started first 32 bits
      // Start first 32 bits
      mem32_req_o   <= 1;
      mem32_addr_o  <= dw_store_addr;
      mem32_wdata_o <= dw_store_wdata[31:0];
      mem32_we_o    <= dw_store_we;
      mem32_be_o    <= dw_store_be[3:0];
    end else if (dw_valid && mem32_req_o && mem32_gnt_i && !dw_first_done) begin // Valid transaction, first output just taken
      dw_first_done <= 1; // First 32 bits is done
      // Clear output
      mem32_req_o   <= 0;
      mem32_we_o    <= '0;
      mem32_be_o    <= '0;
      mem32_addr_o  <= '0;
      mem32_wdata_o <= '0;
    end else if (dw_valid && !mem32_req_o && dw_first_done) begin // Valid transaction, no untaken output, first 32 bits already done
      // Start next 32 bits
      mem32_req_o   <= 1;
      mem32_addr_o  <= dw_store_addr + 4;
      mem32_wdata_o <= dw_store_wdata[63:32];
      mem32_we_o    <= dw_store_we;
      mem32_be_o    <= dw_store_be[7:4];
    end else if (dw_valid && mem32_req_o && mem32_gnt_i && dw_first_done) begin // Valid transaction, second output just taken
      // transaction done
      dw_valid      <= 0;
      dw_first_done <= 0;

      // Clear output
      mem32_req_o   <= 0;
      mem32_we_o    <= '0;
      mem32_be_o    <= '0;
      mem32_addr_o  <= '0;
      mem32_wdata_o <= '0;
    end
  end

  // Check that address bits outside TL address width are zeros for transactions from AXI to TL
  `ASSERT(AxiToTlAddrUpperZeroed,
          mem64_req_i && mem64_gnt_o |-> mem64_addr_i[top_pkg::AxiAddrWidth-1:top_pkg::TL_AW] == '0,
          clk_i, !rst_ni)

  // Receive side upsizer
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      uw_valid <= 0;
      // Clear rdata return
      mem64_rvalid_o <= 0;
      mem64_rdata_o  <= '0;
    end else if (mem64_rvalid_o) begin // Assert upsized output for only 1 cycle
      mem64_rvalid_o <= 0;
    end else if (!uw_valid && mem32_rvalid_i) begin // First 32 bits arrive
      // Store first 32 bits of rdata
      uw_valid         <= 1;
      uw_first32_rdata <= mem32_rdata_i;
    end else if (uw_valid && mem32_rvalid_i) begin // second 32 bits arrive
      // Clear transaction
      uw_valid <= 0;
      // Set upsized output
      mem64_rvalid_o <= 1;
      mem64_rdata_o  <= {mem32_rdata_i, uw_first32_rdata};
    end
  end
endmodule
