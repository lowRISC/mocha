// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Plain AXI subordinate attached to the AXI crossbar's dedicated SwDvWindow device port. It
// provides a dedicated channel for SW <-> DV communication: all traffic reaching this module has
// already been routed here by the crossbar, so no address-range filtering happens in this block.
module sim_sram_axi_sink #(
  parameter bit InstantiateSram = 1'b0, // 1: Instantiate the SRAM memory
  parameter int SramDepth       = 8,    // Depth of the SRAM in words
  parameter bit ErrOnRead       = 1'b1  // 1: Trigger error on CPU read attempt
) (
  input logic clk_i,
  input logic rst_ni,

  // AXI slave port: receives only SW-DV window traffic from the crossbar
  input  top_pkg::axi_dev_req_t  axi_req_i,
  output top_pkg::axi_dev_resp_t axi_resp_o
);

  import top_pkg::*;
  import cva6_config_pkg::*;

  // AXI Protocol conversion to memory interface
  logic                             mem_req;
  logic                             mem_req_d;
  logic                             mem_we;
  logic [top_pkg::AxiAddrWidth-1:0] mem_addr;
  logic [top_pkg::AxiDataWidth-1:0] mem_wdata;
  logic [top_pkg::AxiDataWidth-1:0] mem_rdata;
  logic [top_pkg::AxiStrbWidth-1:0] mem_be;

  // True when the access targets the read-only HW_ID register.
  // axi_to_mem aligns addresses to AxiDataWidth/8 bytes, so compare against the
  // 8-byte aligned hw_id_addr (clearing the lower 3 bits for a 64-bit bus).
  logic hw_id_sel;
  assign hw_id_sel = (mem_addr[31:0] == {u_sim_sram_if.hw_id_addr[31:3], 3'b000});

  // Insert one cycle delay to align with mem_req_d
  logic hw_id_sel_d;
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) hw_id_sel_d <= 1'b0;
    else         hw_id_sel_d <= mem_req && !mem_we && hw_id_sel;
  end

  axi_to_mem #(
    .axi_req_t    (top_pkg::axi_dev_req_t ),
    .axi_resp_t   (top_pkg::axi_dev_resp_t),
    .DataWidth    (top_pkg::AxiDataWidth  ),
    .AddrWidth    (top_pkg::AxiAddrWidth  ),
    .IdWidth      (top_pkg::AxiDevIdWidth ),
    .NumBanks     (1                      )
  ) i_axi_to_mem (
    .clk_i        (clk_i        ),
    .rst_ni       (rst_ni       ),
    .busy_o       (             ),  // Not used
    .axi_req_i    (axi_req_i    ),
    .axi_resp_o   (axi_resp_o   ),
    .mem_req_o    (mem_req      ),
    .mem_gnt_i    (1'b1         ),  // ALWAYS GRANT: Sim SRAM is never busy
    .mem_addr_o   (mem_addr     ),
    .mem_wdata_o  (mem_wdata    ),
    .mem_strb_o   (mem_be       ),
    .mem_atop_o   (             ),  // Not used: Atomics not supported in this path
    .mem_we_o     (mem_we       ),
    .mem_rvalid_i (mem_req_d    ),  // 1-cycle delayed loopback
    .mem_rdata_i  (mem_rdata    )
  );

  // Read Valid Logic (1-cycle delay loopback)
  // Essential for axi_to_mem to complete read AND write transactions even if SRAM is missing.
  always_ff @(posedge clk_i or negedge rst_ni) begin : delayed_mem_req
    if (!rst_ni) begin
      mem_req_d <= 1'b0;
    end else begin
      mem_req_d <= mem_req;
    end
  end : delayed_mem_req

  // Assert Error if ErrOnRead is set and a read occurs to a non-HW_ID address.
  if (ErrOnRead) begin : gen_err_on_read
    `ASSERT(ErrOnRead_A, (mem_req && !hw_id_sel) |-> mem_we, clk_i, !rst_ni)
  end : gen_err_on_read

  // Conditional SRAM Instantiation
  if (InstantiateSram) begin : gen_sram
    // Strobe expansion
    logic [AxiDataWidth-1:0] full_wmask;
    always_comb begin : full_wmask_conversion
      for (int i = 0; i < AxiStrbWidth; i++) begin
        full_wmask[i*8 +: 8] = {8{mem_be[i]}};
      end
    end

    // Calculate the upper bit index for the address based on SramDepth
    localparam int AddrIndexHigh = 4 + $clog2(SramDepth) - 1;

    // OpenTitan RAM Primitive
    prim_ram_1p #(
      .Width (top_pkg::AxiDataWidth ),
      .Depth (SramDepth             )
    ) i_sim_ram (
      .clk_i,
      .rst_ni,
      .req_i     (mem_req                    ),
      .write_i   (mem_we                     ),
      .addr_i    (mem_addr[AddrIndexHigh:4]  ),
      .wdata_i   (mem_wdata                  ),
      .wmask_i   (full_wmask                 ),
      .rdata_o   (mem_rdata                  ),
      .cfg_i     ('0                         ),
      .cfg_rsp_o (                           )
    );
  end : gen_sram
  else begin : gen_no_sram
    // If no SRAM, return hw_id for RO register reads, 0 otherwise.
    // hw_id at byte offset 4 occupies the upper 32 bits of the 64-bit AXI word [63:32].
    assign mem_rdata = hw_id_sel_d ? {u_sim_sram_if.hw_id, {(AxiDataWidth-32){1'b0}}} : '0;
  end : gen_no_sram

  // Simulation SRAM Interface Instance
  sim_sram_axi_if u_sim_sram_if (.clk_i, .rst_ni);
  assign u_sim_sram_if.req  = axi_req_i;
  assign u_sim_sram_if.resp = axi_resp_o;

endmodule : sim_sram_axi_sink
