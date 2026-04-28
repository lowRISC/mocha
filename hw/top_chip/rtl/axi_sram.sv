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

  // Every tag entry can store AxiDataWidth capability tags
  localparam int unsigned TagBitAddrWidth = AddrWidth - $clog2(top_pkg::CapSizeBits / 8);
  localparam int unsigned TagAddrWidth    = TagBitAddrWidth - $clog2(top_pkg::AxiDataWidth);
  localparam int unsigned TagBitWith      = $clog2(top_pkg::AxiDataWidth);

  // 64-bit memory format signals
  logic                                 sram_req;
  logic                                 sram_we_d, sram_we_q;
  logic [(top_pkg::AxiDataWidth/8)-1:0] sram_be;
  logic [    top_pkg::AxiAddrWidth-1:0] sram_addr;
  logic [    top_pkg::AxiDataWidth-1:0] sram_wdata;
  logic                                 sram_rvalid;
  logic [    top_pkg::AxiDataWidth-1:0] sram_rdata;
  logic [                AddrWidth-1:0] sram_word_addr;
  logic [    top_pkg::AxiDataWidth-1:0] sram_wmask;
  logic [          TagBitAddrWidth-1:0] sram_tag_bit_addr;
  logic [             TagAddrWidth-1:0] sram_tag_word_addr;
  logic [               TagBitWith-1:0] sram_tag_bit_select;
  logic [    top_pkg::AxiDataWidth-1:0] sram_tag_wmask;
  logic [    top_pkg::AxiDataWidth-1:0] sram_tag_wdata;
  logic [    top_pkg::AxiDataWidth-1:0] sram_tag_rdata;
  logic                                 sram_cheri_w_tag;
  logic                                 sram_cheri_r_tag;

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
    .mem_err_i       ('0),
    .mem_exokay_i    ('0),
    .mem_we_o        (sram_we_d),
    .mem_cheri_tag_o (sram_cheri_w_tag),
    .mem_rvalid_i    (sram_rvalid),
    // When write is enabled the block requires a read valid response.
    // In this case feed dummy data since otherwise rdata_i is undefined.
    .mem_rdata_i     ((sram_rvalid & sram_we_q) ? 64'hFEED_CAFE_8BAD_F00D : sram_rdata),
    .mem_cheri_tag_i ((sram_rvalid & sram_we_q) ? 1'b0 : sram_cheri_r_tag)
  );

  // Tag bit address calculation
  assign sram_tag_bit_addr   = TagBitAddrWidth'((sram_addr & top_pkg::SRAMMask) >>
                               $clog2(top_pkg::CapSizeBits / 8));
  assign sram_tag_word_addr  = TagAddrWidth'(sram_tag_bit_addr >>
                               $clog2(top_pkg::AxiDataWidth));
  assign sram_tag_bit_select = sram_tag_bit_addr[$clog2(top_pkg::AxiDataWidth)-1:0];

  // Shift tag bit to proper position within SRAM word
  assign sram_tag_wmask      = 1'b1 << sram_tag_bit_select;
  assign sram_tag_wdata      = { {top_pkg::AxiDataWidth-1{1'b0}}, sram_cheri_w_tag } <<
                               sram_tag_bit_select;
  assign sram_cheri_r_tag    = sram_tag_rdata[sram_tag_bit_select];

  // Tag RAM
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 1                     ),
    .Depth           ( 2 ** TagAddrWidth     )
  ) u_tag_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (sram_req),
    .write_i (sram_we_d),
    .addr_i  (sram_tag_word_addr),
    .wdata_i (sram_tag_wdata),
    .wmask_i (sram_tag_wmask),
    .rdata_o (sram_tag_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Remove base offset and convert byte address to 64-bit word address
  assign sram_word_addr = AddrWidth'((sram_addr & top_pkg::SRAMMask) >> $clog2(top_pkg::AxiDataWidth / 8));
  always_comb begin
    for (int i = 0; i < (top_pkg::AxiDataWidth / 8); ++i) begin
      sram_wmask[i*8 +: 8] = {8{sram_be[i]}};
    end
  end

  // Our RAM
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( 2 ** AddrWidth        ),
    .MemInitFile     ( MemInitFile           )
  ) u_ram (
    .clk_i  ( clk_i  ),
    .rst_ni ( rst_ni ),

    .req_i   (sram_req),
    .write_i (sram_we_d),
    .addr_i  (sram_word_addr),
    .wdata_i (sram_wdata),
    .wmask_i (sram_wmask),
    .rdata_o (sram_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sram_rvalid <= 1'b0;
      sram_we_q   <= 1'b0;
    end else begin
      sram_rvalid <= sram_req; // Generate rvalid strobes even for writes
      sram_we_q   <= sram_we_d;
    end
  end

endmodule
