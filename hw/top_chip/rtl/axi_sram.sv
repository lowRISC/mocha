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
  // Local parameters
  localparam int unsigned TagAw       = AddrWidth - 1;
  localparam int unsigned CapSizeBits = 128; // Size of capability excluding valid bit

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

  // AXI response from SRAM before inserting cap valid bit
  top_pkg::axi_resp_t tag_pre_insert_resp;

  // Tag memory signals
  logic             tag_mem_a_req_i;
  logic [TagAw-1:0] tag_mem_a_addr_i;
  top_pkg::user_t   tag_mem_a_wdata_i;
  logic             tag_mem_b_req_i;
  logic [TagAw-1:0] tag_mem_b_addr_i;
  top_pkg::user_t   tag_mem_b_rdata_o;

  // Capability valid bit insertion

  // Assume AW data unchanged until W finished
  assign tag_mem_a_req_i   = axi_resp_o.w_ready && axi_req_i.w_valid && axi_req_i.w.last;
  assign tag_mem_a_addr_i  = TagAw'((axi_req_i.aw.addr & top_pkg::SRAMMask) >> $clog2(CapSizeBits / 8));
  assign tag_mem_a_wdata_i = axi_req_i.w.user;
  assign tag_mem_b_req_i   = axi_resp_o.ar_ready && axi_req_i.ar_valid;
  assign tag_mem_b_addr_i  = TagAw'((axi_req_i.ar.addr & top_pkg::SRAMMask) >> $clog2(CapSizeBits / 8));

  // Tag memory
  prim_ram_2p #(
    .Width           ( 1          ),
    .Depth           ( 2 ** TagAw ),
    .DataBitsPerMask ( 1          )
  ) u_tag_mem_prim (
    // Write port
    .clk_a_i   (clk_i),
    .a_req_i   (tag_mem_a_req_i),
    .a_write_i (1'b1),
    .a_addr_i  (tag_mem_a_addr_i),
    .a_wdata_i (tag_mem_a_wdata_i),
    .a_wmask_i ('1),
    .a_rdata_o ( ),

    // Read port
    .clk_b_i   (clk_i),
    .b_req_i   (tag_mem_b_req_i),
    .b_write_i (1'b0),
    .b_addr_i  (tag_mem_b_addr_i),
    .b_wdata_i ('0),
    .b_wmask_i ('1),
    .b_rdata_o (tag_mem_b_rdata_o),

    .cfg_i     ('0),
    .cfg_rsp_o ()
  );

  // Replace only user field with cap valid bit read from tag memory
  always_comb begin
    axi_resp_o        = tag_pre_insert_resp;
    axi_resp_o.r.user = tag_mem_b_rdata_o;
  end

  // Partial read of capability not currently supported
  // Not using assert macro since prim_assert.sv selects dummy macros in verilator, and
  // trying to override this causes macro redefinition errors

  // SRAM R channel response starts 1 cycle after AR channel request (assumed by NoPartialCapRead assertion)
  SRAMLatency1Cycle: assert property (
    @(posedge clk_i) disable iff (rst_ni === '0) (
      $rose(axi_resp_o.r_valid)
      |-> $past(axi_resp_o.ar_ready && axi_req_i.ar_valid)
    )
  ) else begin
    `ASSERT_ERROR(SRAMLatency1Cycle)
  end

  // All reads that return valid capability tag must not be partial reads
  NoPartialCapRead: assert property (
    @(posedge clk_i) disable iff (rst_ni === '0) (
      axi_resp_o.ar_ready &&
      axi_req_i.ar_valid &&
      axi_req_i.ar.len < 1
      |=> axi_resp_o.r_valid && axi_resp_o.r.user == '0
    )
  ) else begin
    $display("ERROR: Partial capability read not supported!");
    `ASSERT_ERROR(NoPartialCapRead)
  end

  // AXI to 64-bit mem for SRAM
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_sram_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (axi_req_i),
    .axi_resp_o (tag_pre_insert_resp),

    // Memory interface.
    .mem_req_o    (sram_req),
    .mem_gnt_i    (1'b1),
    .mem_addr_o   (sram_addr),
    .mem_wdata_o  (sram_wdata),
    .mem_strb_o   (sram_be),
    .mem_atop_o   ( ),
    .mem_we_o     (sram_we),
    .mem_rvalid_i (sram_rvalid),
    .mem_rdata_i  (sram_rdata)
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
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( 2 ** AddrWidth        ),
    .MemInitFile     ( MemInitFile           )
  ) u_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (sram_req),
    .write_i (sram_we),
    .addr_i  (sram_word_addr),
    .wdata_i (sram_wdata),
    .wmask_i (sram_wmask),
    .rdata_o (sram_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) sram_rvalid <= '0;
    else         sram_rvalid <= sram_req; // Generate rvalid strobes even for writes
  end
endmodule
