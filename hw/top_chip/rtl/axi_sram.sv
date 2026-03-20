// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module axi_sram #(
  parameter int AddrWidth   = 14,
  parameter     MemInitFile = ""
) (
  // Clock and reset.
  input  logic clk_i,
  input  logic rst_ni,

  // Capability AXI interface
  input  top_pkg::axi_req_t  axi_req_i,
  output top_pkg::axi_resp_t axi_resp_o
);

  // 64-bit memory format signals
  logic                                 sram_req;
  logic                                 sram_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] sram_be;
  logic [top_pkg::AxiAddrWidth-1:0]     sram_addr;
  logic [top_pkg::AxiDataWidth-1:0]     sram_wdata;
  logic                                 sram_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     sram_rdata;
  logic [AddrWidth-1:0]                 sram_word_addr;
  logic [top_pkg::AxiDataWidth-1:0]     sram_wmask;
  logic                                 sram_cheri_w_tag;
  logic                                 sram_cheri_r_tag;


  // SRAM R channel response starts 1 cycle after AR channel request (assumed by NoPartialCapRead assertion)
  SRAMLatency1Cycle: assert property (
    @(posedge clk_i) disable iff (rst_ni === '0) (
      $rose(axi_resp_o.r_valid)
      |-> $past(axi_resp_o.ar_ready && axi_req_i.ar_valid)
    )
  ) else begin
    `ASSERT_ERROR(SRAMLatency1Cycle)
  end


  // AXI to 64-bit mem for SRAM
  axi_to_detailed_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_axi_to_detailed_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (axi_req_i),
    .axi_resp_o (axi_resp_o),

    // Memory interface.
    .mem_req_o       (sram_req),
    .mem_gnt_i       (1'b1),
    .mem_addr_o      (sram_addr),
    .mem_wdata_o     (sram_wdata),
    .mem_strb_o      (sram_be),
    .mem_atop_o      ( ),
    .mem_lock_o      ( ),
    .mem_id_o        ( ),
    .mem_user_o      ( ),
    .mem_cache_o     ( ),
    .mem_prot_o      ( ),
    .mem_qos_o       ( ),
    .mem_region_o    ( ),
    .mem_err_i       ( ),
    .mem_exokay_i    ( ),
    .mem_we_o        (sram_we),
    .mem_cheri_tag_o (sram_cheri_w_tag),
    .mem_rvalid_i    (sram_rvalid),
    .mem_rdata_i     (sram_rdata),
    .mem_cheri_tag_i (sram_cheri_r_tag)
  );

  // Remove base offset and convert byte address to 64-bit word address
  assign sram_word_addr = AddrWidth'((sram_addr & top_pkg::SRAMMask) >> $clog2(top_pkg::AxiDataWidth / 8));
  always_comb begin
    for (int i=0; i < (top_pkg::AxiDataWidth / 8); ++i) begin
      sram_wmask[i*8 +: 8] = {8{sram_be[i]}};
    end
  end

  // Our RAM
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth + 32'd1 ),
    .DataBitsPerMask ( 1                             ),
    .Depth           ( 2 ** AddrWidth                ),
    .MemInitFile     ( MemInitFile                   )
  ) u_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (sram_req),
    .write_i (sram_we),
    .addr_i  (sram_word_addr),
    .wdata_i ({ sram_cheri_w_tag, sram_wdata }),
    .wmask_i ({ 1'b1,             sram_wmask }),
    .rdata_o ({ sram_cheri_r_tag, sram_rdata }),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sram_rvalid <= '0;
    else         sram_rvalid <= sram_req; // Generate rvalid strobes even for writes
  end

endmodule
