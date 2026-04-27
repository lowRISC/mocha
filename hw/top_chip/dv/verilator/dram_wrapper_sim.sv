// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module dram_wrapper_sim (
  // Clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // AXI interface
  // ID is 1 bit wider than normal
  input  top_pkg::axi_dram_req_t  axi_req_i,
  output top_pkg::axi_dram_resp_t axi_resp_o
);
  // Local parameters
  localparam int unsigned ExtMemAddrWidth = $clog2(top_pkg::DRAMPhysicalLength / (top_pkg::AxiDataWidth / 8));

  // 64-bit memory format signals
  logic                                 ext_mem_req;
  logic                                 ext_mem_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] ext_mem_be;
  logic [    top_pkg::AxiAddrWidth-1:0] ext_mem_addr;
  logic [    top_pkg::AxiDataWidth-1:0] ext_mem_wdata;
  logic                                 ext_mem_rvalid;
  logic [    top_pkg::AxiDataWidth-1:0] ext_mem_rdata;
  logic [          ExtMemAddrWidth-1:0] ext_mem_word_addr;
  logic [    top_pkg::AxiDataWidth-1:0] ext_mem_wmask;

  // AXI to 64-bit mem for mock external memory
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_dram_req_t  ),
    .axi_resp_t ( top_pkg::axi_dram_resp_t ),
    .AddrWidth  ( top_pkg::AxiAddrWidth    ),
    .DataWidth  ( top_pkg::AxiDataWidth    ),
    .IdWidth    ( top_pkg::AxiIdWidth + 1  ),
    .NumBanks   ( 1                        )
  ) u_ext_mem_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (axi_req_i),
    .axi_resp_o (axi_resp_o),

    // Memory interface.
    .mem_req_o    (ext_mem_req),
    .mem_gnt_i    (1'b1),
    .mem_addr_o   (ext_mem_addr),
    .mem_wdata_o  (ext_mem_wdata),
    .mem_strb_o   (ext_mem_be),
    .mem_atop_o   ( ),
    .mem_we_o     (ext_mem_we),
    .mem_rvalid_i (ext_mem_rvalid),
    .mem_rdata_i  (ext_mem_rdata)
  );

  // Convert byte address to 64-bit word address
  assign ext_mem_word_addr = ExtMemAddrWidth'(ext_mem_addr >> $clog2(top_pkg::AxiDataWidth / 8));

  // Generate wmask from byte enable
  always_comb begin
    for (int i=0; i < (top_pkg::AxiDataWidth / 8); ++i) begin
      ext_mem_wmask[i*8 +: 8] = {8{ext_mem_be[i]}};
    end
  end

  // Mock external memory
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( 2 ** ExtMemAddrWidth  )
  ) u_ext_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (ext_mem_req),
    .write_i (ext_mem_we),
    .addr_i  (ext_mem_word_addr),
    .wdata_i (ext_mem_wdata),
    .wmask_i (ext_mem_wmask),
    .rdata_o (ext_mem_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) ext_mem_rvalid <= '0;
    else         ext_mem_rvalid <= ext_mem_req; // Generate rvalid strobes even for writes
  end
endmodule
