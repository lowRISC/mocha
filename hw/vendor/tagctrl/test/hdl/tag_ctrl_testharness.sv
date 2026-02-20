// Copyright 2023 Bruno Sá and ZeroDay Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author:
// - Bruno Sá

/// Testbench for the module `axi_tag_ctrl_top`.
`include "axi/typedef.svh"
`include "axi/assign.svh"
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"
module tag_ctrl_testharness #(
    parameter int unsigned AXI_ADDR_WIDTH = 64'd64,
    parameter int unsigned AXI_DATA_WIDTH = 64'd64,
    parameter int unsigned AXI_ID_WIDTH   = 64'd6,
    parameter int unsigned AXI_USER_WIDTH = 64'd1,
    parameter int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8
) (
    input  logic                                 clk_i,         /// Clock
    input  logic                                 rst_ni,        /// Asynchronous reset active low
    input  logic            [  AXI_ID_WIDTH-1:0] cpu_aw_id,
    input  logic            [AXI_ADDR_WIDTH-1:0] cpu_aw_addr,
    input  axi_pkg::len_t                        cpu_aw_len,
    input  axi_pkg::size_t                       cpu_aw_size,
    input  axi_pkg::burst_t                      cpu_aw_burst,
    input  logic            [AXI_USER_WIDTH-1:0] cpu_aw_user,
    input  logic                                 cpu_aw_valid,
    output logic                                 cpu_aw_ready,

    input  logic [AXI_DATA_WIDTH-1:0] cpu_w_data,
    input  logic [AXI_STRB_WIDTH-1:0] cpu_w_strb,
    input  logic                      cpu_w_last,
    input  logic [AXI_USER_WIDTH-1:0] cpu_w_user,
    input  logic                      cpu_w_valid,
    output logic                      cpu_w_ready,

    output logic           [  AXI_ID_WIDTH-1:0] cpu_b_id,
    output axi_pkg::resp_t                      cpu_b_resp,
    output logic           [AXI_USER_WIDTH-1:0] cpu_b_user,
    output logic                                cpu_b_valid,
    input  logic                                cpu_b_ready,

    input  logic            [  AXI_ID_WIDTH-1:0] cpu_ar_id,
    input  logic            [AXI_ADDR_WIDTH-1:0] cpu_ar_addr,
    input  axi_pkg::len_t                        cpu_ar_len,
    input  axi_pkg::size_t                       cpu_ar_size,
    input  axi_pkg::burst_t                      cpu_ar_burst,
    input  logic            [AXI_USER_WIDTH-1:0] cpu_ar_user,
    input  logic                                 cpu_ar_valid,
    output logic                                 cpu_ar_ready,

    output logic           [  AXI_ID_WIDTH-1:0] cpu_r_id,
    output logic           [AXI_DATA_WIDTH-1:0] cpu_r_data,
    output axi_pkg::resp_t                      cpu_r_resp,
    output logic                                cpu_r_last,
    output logic           [AXI_USER_WIDTH-1:0] cpu_r_user,
    output logic                                cpu_r_valid,
    input  logic                                cpu_r_ready
);
  /*verilator public_on*/
  localparam int unsigned CapSize = 128;
  localparam int unsigned NUM_WORDS = 2 ** 25;  // memory size
  localparam int unsigned DRAMMemBase = {64'h80000000};
  localparam int unsigned DRAMMemLength = {64'h40000000};
  localparam int unsigned TagCacheMemBase = {64'hA0000000};
  localparam int unsigned TagCacheMemLength = {64'h00010000};
  localparam int unsigned AxiIdWidth = 64'd6;
  localparam int unsigned AxiAddrWidth = 64'd64;
  localparam int unsigned AxiDataWidth = 64'd64;
  localparam int unsigned AxiUserWidth = 64'd1;
  localparam int unsigned SetAssociativity = 32'd8;
  localparam int unsigned NumLines = 32'd128;
  localparam int unsigned NumBlocks = 32'd4;
  /*verilator public_off*/
  /////////////////////////////
  // Axi channel definitions //
  /////////////////////////////
  localparam int unsigned AxiStrbWidth = AxiDataWidth / 32'd8;
  typedef logic [AxiIdWidth-1:0] axi_slv_id_t;
  typedef logic [AxiIdWidth:0] axi_mst_id_t;
  typedef logic [AxiAddrWidth-1:0] axi_addr_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [AxiStrbWidth-1:0] axi_strb_t;
  typedef logic [AxiUserWidth-1:0] axi_user_t;
  typedef logic [7:0] byte_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_slv_aw_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AW_CHAN_T(axi_mst_aw_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_slv_b_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_mst_b_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_slv_ar_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_mst_ar_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_slv_r_t, axi_data_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_mst_r_t, axi_data_t, axi_mst_id_t, axi_user_t)

  `AXI_TYPEDEF_REQ_T(axi_slv_req_t, axi_slv_aw_t, axi_w_t, axi_slv_ar_t)
  `AXI_TYPEDEF_RESP_T(axi_slv_resp_t, axi_slv_b_t, axi_slv_r_t)
  `AXI_TYPEDEF_REQ_T(axi_mst_req_t, axi_mst_aw_t, axi_w_t, axi_mst_ar_t)
  `AXI_TYPEDEF_RESP_T(axi_mst_resp_t, axi_mst_b_t, axi_mst_r_t)

  `REG_BUS_TYPEDEF_ALL(conf, logic [31:0], logic [31:0], logic [3:0])

  // rule definitions
  typedef struct packed {
    int unsigned idx;
    axi_addr_t   start_addr;
    axi_addr_t   end_addr;
  } rule_full_t;

  localparam axi_addr_t CachedRegionStart = axi_addr_t'(TagCacheMemBase);
  localparam axi_addr_t CachedRegionLength = axi_addr_t'(2 * TagCacheMemLength);

  // AXI channels
  axi_slv_req_t  axi_cpu_req;
  axi_slv_resp_t axi_cpu_res;
  axi_mst_req_t  axi_mem_req;
  axi_mst_resp_t axi_mem_res;

  AXI_BUS #(
      .AXI_ADDR_WIDTH(AxiAddrWidth),
      .AXI_DATA_WIDTH(AxiDataWidth),
      .AXI_ID_WIDTH  (AxiIdWidth),
      .AXI_USER_WIDTH(AxiUserWidth)
  ) axi_cpu ();

  AXI_BUS #(
      .AXI_ADDR_WIDTH(AxiAddrWidth),
      .AXI_DATA_WIDTH(AxiDataWidth),
      .AXI_ID_WIDTH  (AxiIdWidth + 64'd1),
      .AXI_USER_WIDTH(AxiUserWidth)
  ) axi_dram ();

  `AXI_ASSIGN_TO_REQ(axi_cpu_req, axi_cpu)
  `AXI_ASSIGN_FROM_RESP(axi_cpu, axi_cpu_res)

  assign axi_cpu.aw_id = cpu_aw_id;
  assign axi_cpu.aw_addr = cpu_aw_addr;
  assign axi_cpu.aw_len = cpu_aw_len;
  assign axi_cpu.aw_size = cpu_aw_size;
  assign axi_cpu.aw_burst = cpu_aw_burst;
  assign axi_cpu.aw_user = cpu_aw_user;
  assign axi_cpu.aw_valid = cpu_aw_valid;

  assign cpu_aw_ready = axi_cpu.aw_ready;

  assign axi_cpu.w_data = cpu_w_data;
  assign axi_cpu.w_strb = cpu_w_strb;
  assign axi_cpu.w_last = cpu_w_last;
  assign axi_cpu.w_user = cpu_w_user;
  assign axi_cpu.w_valid = cpu_w_valid;

  assign cpu_w_ready = axi_cpu.w_ready;

  assign cpu_b_id = axi_cpu.b_id;
  assign cpu_b_resp = axi_cpu.b_resp;
  assign cpu_b_user = axi_cpu.b_user;
  assign cpu_b_valid = axi_cpu.b_valid;

  assign axi_cpu.b_ready = cpu_b_ready;

  assign axi_cpu.ar_id = cpu_ar_id;
  assign axi_cpu.ar_addr = cpu_ar_addr;
  assign axi_cpu.ar_len = cpu_ar_len;
  assign axi_cpu.ar_size = cpu_ar_size;
  assign axi_cpu.ar_burst = cpu_ar_burst;
  assign axi_cpu.ar_lock = '0;
  assign axi_cpu.ar_cache = '0;
  assign axi_cpu.ar_prot = '0;
  assign axi_cpu.ar_qos = '0;
  assign axi_cpu.ar_region = '0;
  assign axi_cpu.ar_user = cpu_ar_user;
  assign axi_cpu.ar_valid = cpu_ar_valid;

  assign cpu_ar_ready = axi_cpu.ar_ready;

  assign cpu_r_id = axi_cpu.r_id;
  assign cpu_r_data = axi_cpu.r_data;
  assign cpu_r_resp = axi_cpu.r_resp;
  assign cpu_r_last = axi_cpu.r_last;
  assign cpu_r_user = axi_cpu.r_user;
  assign cpu_r_valid = axi_cpu.r_valid;

  assign axi_cpu.r_ready = cpu_r_ready;

  `AXI_ASSIGN_FROM_REQ(axi_dram, axi_mem_req)
  `AXI_ASSIGN_TO_RESP(axi_mem_res, axi_dram)

  logic                      dram_req;
  logic                      dram_we;
  logic [  AxiAddrWidth-1:0] dram_addr;
  logic [AxiDataWidth/8-1:0] dram_be;
  logic [  AxiDataWidth-1:0] dram_wdata;
  logic [  AxiDataWidth-1:0] dram_rdata;
  logic [  AxiUserWidth-1:0] dram_wuser;
  logic [  AxiUserWidth-1:0] dram_ruser;
  logic                      dram_rvalid;

  ////////////////////////////
  // AXI Tag Controller DUT //
  ////////////////////////////
  axi_tagctrl_reg_wrap #(
      .DRAMMemBase     (DRAMMemBase),
      .CapSize         (CapSize),
      .TagCacheMemBase (TagCacheMemBase),
      .SetAssociativity(SetAssociativity),
      .NumLines        (NumLines),
      .NumBlocks       (NumBlocks),
      .AxiIdWidth      (AxiIdWidth),
      .AxiAddrWidth    (AxiAddrWidth),
      .AxiDataWidth    (AxiDataWidth),
      .AxiUserWidth    (AxiUserWidth),
      .slv_req_t       (axi_slv_req_t),
      .slv_resp_t      (axi_slv_resp_t),
      .mst_req_t       (axi_mst_req_t),
      .mst_resp_t      (axi_mst_resp_t),
      .reg_req_t       (conf_req_t),
      .reg_resp_t      (conf_rsp_t),
      .rule_full_t     (rule_full_t),
      .PrintSramCfg    (1'b0)
  ) i_axi_tagctrl_reg_wrap_raw (
      .clk_i,
      .rst_ni,
      .test_i             (1'b0),
      .slv_req_i          (axi_cpu_req),
      .slv_resp_o         (axi_cpu_res),
      .mst_req_o          (axi_mem_req),
      .mst_resp_i         (axi_mem_res),
      .conf_req_i         (  /* not used */),
      .conf_resp_o        (  /* not used */),
      .cached_start_addr_i(CachedRegionStart),
      .cached_end_addr_i  (CachedRegionLength)
  );

  /*   AXI_BUS #(
      .AXI_ADDR_WIDTH(AxiAddrWidth),
      .AXI_DATA_WIDTH(AxiDataWidth),
      .AXI_ID_WIDTH  (AxiIdWidth + 1),
      .AXI_USER_WIDTH(AxiUserWidth)
  ) axi_dram_delayed ();


  axi_delayer_intf #(
      .AXI_ID_WIDTH       (AxiIdWidth),
      .AXI_ADDR_WIDTH     (AxiAddrWidth),
      .AXI_DATA_WIDTH     (AxiDataWidth),
      .AXI_USER_WIDTH     (AxiUserWidth),
      .STALL_RANDOM_INPUT (0),
      .STALL_RANDOM_OUTPUT(0),
      .FIXED_DELAY_INPUT  (0),
      .FIXED_DELAY_OUTPUT (0)
  ) i_axi_delayer (
      .clk_i,
      .rst_ni,
      .slv(axi_dram),
      .mst(axi_dram_delayed)
  ); */

  axi2mem #(
      .AXI_ID_WIDTH  (AxiIdWidth + 1),
      .AXI_ADDR_WIDTH(AxiAddrWidth),
      .AXI_DATA_WIDTH(AxiDataWidth),
      .AXI_USER_WIDTH(AxiUserWidth)
  ) i_axi2mem (
      .clk_i,
      .rst_ni,
      .slave (axi_dram),
      .req_o (dram_req),
      .we_o  (dram_we),
      .addr_o(dram_addr),
      .be_o  (dram_be),
      .user_o(dram_wuser),
      .data_o(dram_wdata),
      .user_i(dram_ruser),
      .data_i(dram_rdata)
  );

  sram #(
      .DATA_WIDTH(AxiDataWidth),
      .USER_WIDTH(AxiUserWidth),
      .USER_EN   (1'b0),
`ifdef VERILATOR
      .SIM_INIT  ("none"),
`else
      .SIM_INIT  ("zeros"),
`endif
      .NUM_WORDS (NUM_WORDS)
  ) i_tc_sram (
      .clk_i,
      .rst_ni,
      .req_i  (dram_req),
      .we_i   (dram_we),
      .addr_i (dram_addr[$clog2(NUM_WORDS)-1+$clog2(AxiDataWidth/8):$clog2(AxiDataWidth/8)]),
      .wuser_i(dram_wuser),
      .wdata_i(dram_wdata),
      .be_i   (dram_be),
      .ruser_o(dram_ruser),
      .rdata_o(dram_rdata)
  );

endmodule
