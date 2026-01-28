// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Block inserted between the CPU and the AXI-Crossbar, it intercepts the AXI traffic within the
// simulation memory range to provide a dedicated channel for SW <-> DV communication. The AXI
// traffic within the SW DV range falls into a "sink".
// AXI traffic outside this range is transparently forwarded to the AXI Crossbar.
module sim_sram_axi_sink # (
  parameter bit InstantiateSram = 1'b0, // 1: Instantiate the SRAM memory
  parameter int SramDepth       = 8,    // Depth of the SRAM in words
  parameter bit ErrOnRead       = 1'b1  // 1: Trigger error on CPU read attempt
) (
  input logic clk_i,
  input logic rst_ni,

  // Interface from CVA6 CPU
  input  top_pkg::axi_req_t  cpu_req_i,
  output top_pkg::axi_resp_t cpu_resp_o,

  // Interface to AXI Crossbar
  output top_pkg::axi_req_t  xbar_req_o,
  input  top_pkg::axi_resp_t xbar_resp_i
);

  import top_pkg::*;
  import cva6_config_pkg::*;

  // Internal AXI signals for the intercepted path
  axi_req_t  sim_req;
  axi_resp_t sim_resp;

  logic aw_select;
  logic ar_select;

  // Selection Logic
  assign aw_select  = (cpu_req_i.aw.addr >= u_sim_sram_if.start_addr) &&
                      (cpu_req_i.aw.addr < u_sim_sram_if.start_addr + u_sim_sram_if.sw_dv_size);
  assign ar_select  = (cpu_req_i.ar.addr >= u_sim_sram_if.start_addr) &&
                      (cpu_req_i.ar.addr < u_sim_sram_if.start_addr + u_sim_sram_if.sw_dv_size);

  // AXI Demux: index 0 = System Bus, index 1 = Sim Sink
  axi_demux_simple #(
    .AxiIdWidth       (AxiIdWidth             ),
    .AtopSupport      (1'b0                   ),
    .axi_req_t        (axi_req_t              ),
    .axi_resp_t       (axi_resp_t             ),
    .NoMstPorts       (2                      ),
    .MaxTrans         (8                      )
  ) i_axi_demux (
    .clk_i,
    .rst_ni,
    .test_i           (1'b0                   ),
    .slv_req_i        (cpu_req_i              ),
    .slv_aw_select_i  (aw_select              ),
    .slv_ar_select_i  (ar_select              ),
    .slv_resp_o       (cpu_resp_o             ),
    .mst_reqs_o       ({sim_req,  xbar_req_o} ),
    .mst_resps_i      ({sim_resp, xbar_resp_i})
  );

  // AXI Protocol conversion to memory interface
  logic mem_req;
  logic mem_req_d;
  logic mem_we;
  logic [top_pkg::AxiAddrWidth-1:0] mem_addr;
  logic [top_pkg::AxiDataWidth-1:0] mem_wdata;
  logic [top_pkg::AxiDataWidth-1:0] mem_rdata;
  logic [top_pkg::AxiStrbWidth-1:0] mem_be;

  axi_to_mem #(
    .axi_req_t    (top_pkg::axi_req_t     ),
    .axi_resp_t   (top_pkg::axi_resp_t    ),
    .DataWidth    (top_pkg::AxiDataWidth  ),
    .AddrWidth    (top_pkg::AxiAddrWidth  ),
    .IdWidth      (top_pkg::AxiIdWidth    ),
    .NumBanks     (1                      )
  ) i_axi_to_mem (
    .clk_i        (clk_i        ),
    .rst_ni       (rst_ni       ),
    .busy_o       (             ),  // Not used
    .axi_req_i    (sim_req      ),
    .axi_resp_o   (sim_resp     ),
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
  always_ff @(posedge clk_i or negedge rst_ni) begin: delayed_mem_req
    if (!rst_ni) begin
      mem_req_d <= 1'b0;
    end else begin
      mem_req_d <= mem_req;
    end
  end : delayed_mem_req

  // Assert Error if ErrOnRead is set and a read occurs
  if (ErrOnRead) begin : gen_err_on_read
    `ASSERT(ErrOnRead_A, mem_req |-> mem_we, clk_i, !rst_ni)
  end : gen_err_on_read

  // Conditional SRAM Instantiation
  if (InstantiateSram) begin : gen_sram
    // Strobe expansion
    logic [AxiDataWidth-1:0] full_wmask;
    always_comb begin: full_wmask_conversion
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
    // If no SRAM, return 0s on read.
    // Handshaking is handled by the common logic and axi_to_mem.
    assign mem_rdata = '0;
  end : gen_no_sram

  // Simulation SRAM Interface Instance
  sim_sram_axi_if u_sim_sram_if (.clk_i, .rst_ni);
  assign u_sim_sram_if.req  = sim_req;
  assign u_sim_sram_if.resp = sim_resp;

endmodule : sim_sram_axi_sink
