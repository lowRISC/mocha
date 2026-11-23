// This module is the toplevel module of the tag lookup engine
// it instanciates
// * a tag_lookup_engine_config module
// * tag_lookup_engine_table_lookups module
// * per lookup stream caches
// * an axi_mux to produce a single stream of tag requests

`include "axi/typedef.svh"

import lookup_engine_hpdcache_cfg_pkg::*;

module tag_lookup_engine #(
  parameter type tag_req_t = logic,
  parameter type tag_data_req_t = logic,
  parameter type tag_write_resp_t = logic,
  parameter type tag_read_resp_t = logic,
  parameter int unsigned AxiMstIdWidth = 64'd6,
  parameter int unsigned AxiAddrWidth = 64'd64,
  parameter int unsigned AxiDataWidth = 64'd64,
  parameter int unsigned AxiUserWidth = 64'd0,
  parameter type mem_req_t = logic,
  parameter type mem_resp_t = logic,
  parameter type axi_addr_t = logic [AxiAddrWidth-1:0],
  parameter int unsigned GROUPING_FACTOR = 256,
  parameter int unsigned ROOT_CACHE_WAYS = 4,
  parameter int unsigned ROOT_CACHE_BYTE_SIZE = 2048,
  parameter int unsigned LEAF_CACHE_WAYS = 4,
  parameter int unsigned LEAF_CACHE_BYTE_SIZE = 16384
) (
  // Rising-edge clock of all ports.
  input logic clk_i,
  // Asynchronous reset, active low
  input logic rst_ni,

  // tag store signals //
  ///////////////////////
  input axi_addr_t root_table_base_addr_i,
  input axi_addr_t root_table_top_addr_i,
  input axi_addr_t leaf_table_base_addr_i,
  input axi_addr_t leaf_table_top_addr_i,

  // commands and reporting signals //
  ////////////////////////////////////
  input logic perform_zeroing_i,
  output logic done_zeroing_o,
  input logic perform_flushing_i,
  output logic done_flushing_o,

  // tag controller slave interfaces //
  /////////////////////////////////////
  // incoming tag read request descriptor
  input logic read_req_valid_i,
  output logic read_req_ready_o,
  input tag_req_t read_req_i,
  // outgoing read response
  output logic read_resp_valid_o,
  input logic read_resp_ready_i,
  output tag_read_resp_t read_resp_o,
  // incoming tag write request descriptor
  input logic write_req_valid_i,
  output logic write_req_ready_o,
  input tag_req_t write_req_i,
  // incoming write data
  input logic write_data_req_valid_i,
  output logic write_data_req_ready_o,
  input tag_data_req_t write_data_req_i,
  // outgoing write response
  output logic write_resp_valid_o,
  input logic write_resp_ready_i,
  output tag_write_resp_t write_resp_o,

  // tag store master interfaces //
  /////////////////////////////////
  output mem_req_t mem_req_o,
  input mem_resp_t mem_resp_i,

  // performance events //
  ////////////////////////
  output axi_tagctrl_pkg::tag_lookup_engine_events_t events_o
);

  //////////////////////////////////////////////////////////////////////////////
  // local types and assertions
  //////////////////////////////////////////////////////////////////////////////
  // TODO assert that inner AXI id witdh + max Trans fix in outer id width
  //assert (AxiAddrWidth < 2) $error("tag_lookup_engine: the AXI ID width configuration is not supported");

  // derive AXI types for inner (axi_mux slave) and outer (axi_mux master) traffic
  typedef logic [AxiMstIdWidth-2:0] axi_slv_id_t;
  typedef logic [AxiMstIdWidth-1:0] axi_mst_id_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [(AxiDataWidth/8)-1:0] axi_strb_t;
  typedef logic [0:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, axi_data_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_REQ_T(slv_req_t, slv_aw_chan_t, w_chan_t, slv_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(slv_resp_t, slv_b_chan_t, slv_r_chan_t)

  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_chan_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(mst_b_chan_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_chan_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(mst_r_chan_t, axi_data_t, axi_mst_id_t, axi_user_t)

  // HPDCache wrapper parameters for root and leaf caches
  localparam int unsigned nRootReadPorts = 64'd2;
  localparam int unsigned nRootWritePorts = 64'd2;
  localparam hpdcache_pkg::hpdcache_user_cfg_t root_hpdcache_cfg =
    make_hpdcache_user_cfg(nRootReadPorts+nRootWritePorts, ROOT_CACHE_WAYS, ROOT_CACHE_BYTE_SIZE);
  localparam int unsigned nLeafReadPorts = 64'd2;
  localparam int unsigned nLeafWritePorts = 64'd1;
  localparam hpdcache_pkg::hpdcache_user_cfg_t leaf_hpdcache_cfg =
    make_hpdcache_user_cfg(nLeafReadPorts+nLeafWritePorts, LEAF_CACHE_WAYS, LEAF_CACHE_BYTE_SIZE);

  //////////////////////////////////////////////////////////////////////////////
  // local signals for per table-level accesses (root, leaf)
  //////////////////////////////////////////////////////////////////////////////
  logic root_read_req_valid[2], leaf_read_req_valid[2];
  logic root_read_req_ready[2], leaf_read_req_ready[2];
  logic root_read_req_speculative[2], leaf_read_req_speculative[2];
  tag_req_t root_read_req[2], leaf_read_req[2];
  logic root_write_req_valid[2], leaf_write_req_valid;
  logic root_write_req_ready[2], leaf_write_req_ready;
  tag_req_t root_write_req[2], leaf_write_req;
  logic root_write_req_flush[2], leaf_write_req_flush;
  logic root_write_data_req_valid[2], leaf_write_data_req_valid;
  logic root_write_data_req_ready[2], leaf_write_data_req_ready;
  tag_data_req_t root_write_data_req[2], leaf_write_data_req;
  logic root_write_resp_valid[2], leaf_write_resp_valid;
  logic root_write_resp_ready[2], leaf_write_resp_ready;
  tag_write_resp_t root_write_resp[2], leaf_write_resp;
  logic root_read_resp_valid[2], leaf_read_resp_valid[2];
  logic root_read_resp_ready[2], leaf_read_resp_ready[2];
  tag_read_resp_t root_read_resp[2], leaf_read_resp[2];

  slv_req_t root_mem_req, leaf_mem_req;
  slv_resp_t root_mem_resp, leaf_mem_resp;

  //////////////////////////////////////////////////////////////////////////////
  // generate per table-level accesses
  //////////////////////////////////////////////////////////////////////////////
  tag_lookup_engine_table_lookups #(
    .tag_req_t(tag_req_t),
    .tag_data_req_t(tag_data_req_t),
    .tag_write_resp_t(tag_write_resp_t),
    .tag_read_resp_t(tag_read_resp_t),
    .axi_addr_t(axi_addr_t),
    .axi_slv_id_t(axi_slv_id_t),
    .GROUPING_FACTOR(GROUPING_FACTOR),
    .BITS_PER_ROOT_FLIT(root_hpdcache_cfg.reqWords * root_hpdcache_cfg.wordWidth),
    .BITS_PER_LEAF_FLIT(leaf_hpdcache_cfg.reqWords * leaf_hpdcache_cfg.wordWidth)
  ) i_tag_lookup_engine_table_lookups (
    .clk_i,
    .rst_ni,
    .root_table_size_i(root_table_top_addr_i-root_table_base_addr_i),
    // commands / reporting signals
    .perform_zeroing_i,
    .done_zeroing_o,
    .perform_flushing_i,
    .done_flushing_o,
    // incoming requests interface
    .read_req_valid_i,
    .read_req_ready_o,
    .read_req_i,
    .read_resp_valid_o,
    .read_resp_ready_i,
    .read_resp_o,
    .write_req_valid_i,
    .write_req_ready_o,
    .write_req_i,
    .write_data_req_valid_i,
    .write_data_req_ready_o,
    .write_data_req_i,
    .write_resp_valid_o,
    .write_resp_ready_i,
    .write_resp_o,
    // outgoing interfaces (2 lvls, root, leaf)
    // root level interface
    .root_read_req_valid_o(root_read_req_valid),
    .root_read_req_ready_i(root_read_req_ready),
    .root_read_req_o(root_read_req),
    .root_read_resp_valid_i(root_read_resp_valid),
    .root_read_resp_ready_o(root_read_resp_ready),
    .root_read_resp_i(root_read_resp),
    .root_write_req_valid_o(root_write_req_valid),
    .root_write_req_ready_i(root_write_req_ready),
    .root_write_req_o(root_write_req),
    .root_write_req_flush_o(root_write_req_flush),
    .root_write_data_req_valid_o(root_write_data_req_valid),
    .root_write_data_req_ready_i(root_write_data_req_ready),
    .root_write_data_req_o(root_write_data_req),
    .root_write_resp_valid_i(root_write_resp_valid),
    .root_write_resp_ready_o(root_write_resp_ready),
    .root_write_resp_i(root_write_resp),
    // leaf level interface
    .leaf_read_req_valid_o(leaf_read_req_valid),
    .leaf_read_req_ready_i(leaf_read_req_ready),
    .leaf_read_req_o(leaf_read_req),
    .leaf_read_req_speculative_o(leaf_read_req_speculative),
    .leaf_read_resp_valid_i(leaf_read_resp_valid),
    .leaf_read_resp_ready_o(leaf_read_resp_ready),
    .leaf_read_resp_i(leaf_read_resp),
    .leaf_write_req_valid_o(leaf_write_req_valid),
    .leaf_write_req_ready_i(leaf_write_req_ready),
    .leaf_write_req_o(leaf_write_req),
    .leaf_write_req_flush_o(leaf_write_req_flush),
    .leaf_write_data_req_valid_o(leaf_write_data_req_valid),
    .leaf_write_data_req_ready_i(leaf_write_data_req_ready),
    .leaf_write_data_req_o(leaf_write_data_req),
    .leaf_write_resp_valid_i(leaf_write_resp_valid),
    .leaf_write_resp_ready_o(leaf_write_resp_ready),
    .leaf_write_resp_i(leaf_write_resp),
    // performance events
    .events_o(events_o.lookup_events)
  );

  //////////////////////////////////////////////////////////////////////////////
  // Backing caches
  //////////////////////////////////////////////////////////////////////////////

  assign root_read_req_speculative = '{default: 1'b0};

  // root accesses
  hpdcache_wrapper #(
    .tag_req_t(tag_req_t),
    .tag_data_req_t(tag_data_req_t),
    .tag_write_resp_t(tag_write_resp_t),
    .tag_read_resp_t(tag_read_resp_t),
    .nReadPorts(nRootReadPorts),
    .nWritePorts(nRootWritePorts),
    .AxiIdWidth(AxiMstIdWidth-1),
    .AxiAddrWidth(AxiAddrWidth),
    .AxiDataWidth(AxiDataWidth),
    .AxiUserWidth(AxiUserWidth),
    .mem_req_t(slv_req_t),
    .mem_resp_t(slv_resp_t),
    .axi_addr_t(axi_addr_t),
    .HPDcacheUserCfg(root_hpdcache_cfg)
  ) i_root_tag_cache_wrapper (
    .clk_i,
    .rst_ni,

    // incoming read tag request descriptor
    .read_req_speculative_i(root_read_req_speculative),
    .read_req_valid_i(root_read_req_valid),
    .read_req_ready_o(root_read_req_ready),
    .read_req_i(root_read_req),
    // incoming write tag request descriptor
    .write_req_valid_i(root_write_req_valid),
    .write_req_ready_o(root_write_req_ready),
    .write_req_i(root_write_req),
    .write_req_flush_i(root_write_req_flush),
    // incoming write data
    .write_data_req_valid_i(root_write_data_req_valid),
    .write_data_req_ready_o(root_write_data_req_ready),
    .write_data_req_i(root_write_data_req),
    // outgoing read response
    .read_resp_valid_o(root_read_resp_valid),
    .read_resp_ready_i(root_read_resp_ready),
    .read_resp_o(root_read_resp),
    // outgoing write response
    .write_resp_valid_o(root_write_resp_valid),
    .write_resp_ready_i(root_write_resp_ready),
    .write_resp_o(root_write_resp),

    //// performance events //
    ///////////////////////////////////
    .events_o(events_o.root_cache_events),

    //// tag store memory interfaces //
    ///////////////////////////////////
    .mem_req_o(root_mem_req),
    .mem_resp_i(root_mem_resp)
  );

  // leaf accesses
  logic leaf_write_req_ready_arr[1];
  assign leaf_write_req_ready = leaf_write_req_ready_arr[0];

  logic leaf_write_req_valid_arr[1];
  assign leaf_write_req_valid_arr[0] = leaf_write_req_valid;

  tag_req_t leaf_write_req_arr[1];
  assign leaf_write_req_arr[0] = leaf_write_req;
  logic leaf_write_req_flush_arr[1];
  assign leaf_write_req_flush_arr[0] = leaf_write_req_flush;

  logic leaf_write_data_req_ready_arr[1];
  assign leaf_write_data_req_ready = leaf_write_data_req_ready_arr[0];

  logic leaf_write_data_req_valid_arr[1];
  assign leaf_write_data_req_valid_arr[0] = leaf_write_data_req_valid;

  tag_data_req_t leaf_write_data_req_arr[1];
  assign leaf_write_data_req_arr[0] = leaf_write_data_req;

  logic leaf_write_resp_ready_arr[1];
  assign leaf_write_resp_ready_arr[0] = leaf_write_resp_ready;

  logic leaf_write_resp_valid_arr[1];
  assign leaf_write_resp_valid = leaf_write_resp_valid_arr[0];

  tag_write_resp_t leaf_write_resp_arr[1];
  assign leaf_write_resp = leaf_write_resp_arr[0];

  hpdcache_wrapper #(
    .tag_req_t(tag_req_t),
    .tag_data_req_t(tag_data_req_t),
    .tag_write_resp_t(tag_write_resp_t),
    .tag_read_resp_t(tag_read_resp_t),
    .nReadPorts(nLeafReadPorts),
    .nWritePorts(nLeafWritePorts),
    .AxiIdWidth(AxiMstIdWidth-1),
    .AxiAddrWidth(AxiAddrWidth),
    .AxiDataWidth(AxiDataWidth),
    .AxiUserWidth(AxiUserWidth),
    .mem_req_t(slv_req_t),
    .mem_resp_t(slv_resp_t),
    .axi_addr_t(axi_addr_t),
    .HPDcacheUserCfg(leaf_hpdcache_cfg)
  ) i_leaf_tag_cache_wrapper (
    .clk_i,
    .rst_ni,

    // incoming read tag request descriptor
    .read_req_speculative_i(leaf_read_req_speculative),
    .read_req_valid_i(leaf_read_req_valid),
    .read_req_ready_o(leaf_read_req_ready),
    .read_req_i(leaf_read_req),
    // incoming write tag request descriptor
    .write_req_valid_i(leaf_write_req_valid_arr),
    .write_req_ready_o(leaf_write_req_ready_arr),
    .write_req_i(leaf_write_req_arr),
    .write_req_flush_i(leaf_write_req_flush_arr),
    // incoming write data
    .write_data_req_valid_i(leaf_write_data_req_valid_arr),
    .write_data_req_ready_o(leaf_write_data_req_ready_arr),
    .write_data_req_i(leaf_write_data_req_arr),
    // outgoing read response
    .read_resp_valid_o(leaf_read_resp_valid),
    .read_resp_ready_i(leaf_read_resp_ready),
    .read_resp_o(leaf_read_resp),
    // outgoing write response
    .write_resp_valid_o(leaf_write_resp_valid_arr),
    .write_resp_ready_i(leaf_write_resp_ready_arr),
    .write_resp_o(leaf_write_resp_arr),

    //// performance events //
    ///////////////////////////////////
    .events_o(events_o.leaf_cache_events),

    //// tag store memory interfaces //
    ///////////////////////////////////
    .mem_req_o(leaf_mem_req),
    .mem_resp_i(leaf_mem_resp)
  );

  //////////////////////////////////////////////////////////////////////////////
  // converge tag store memory traffic
  //////////////////////////////////////////////////////////////////////////////

  function automatic slv_req_t table_offset_req(axi_addr_t table_base_addr, slv_req_t req);
    slv_req_t ret = req;
    ret.aw.addr = req.aw.addr + table_base_addr;
    ret.ar.addr = req.ar.addr + table_base_addr;
    return ret;
  endfunction

  axi_mux #(
    .SlvAxiIDWidth(AxiMstIdWidth-1),
    .slv_aw_chan_t(slv_aw_chan_t),
    .mst_aw_chan_t(mst_aw_chan_t),
    .w_chan_t     (w_chan_t),
    .slv_b_chan_t (slv_b_chan_t),
    .mst_b_chan_t (mst_b_chan_t),
    .slv_ar_chan_t(slv_ar_chan_t),
    .mst_ar_chan_t(mst_ar_chan_t),
    .slv_r_chan_t (slv_r_chan_t),
    .mst_r_chan_t (mst_r_chan_t),
    .slv_req_t    (slv_req_t),
    .slv_resp_t   (slv_resp_t),
    .mst_req_t    (mem_req_t),
    .mst_resp_t   (mem_resp_t),
    .NoSlvPorts   (32'd2),
    .MaxWTrans    (32'd8),
    .FallThrough  (1'b0),                   // No registers
    .SpillAw      (1'b0),                   // No registers
    .SpillW       (1'b0),                   // No registers
    .SpillB       (1'b0),                   // No registers
    .SpillAr      (1'b0),                   // No registers
    .SpillR       (1'b0)                    // No registers
  ) i_axi_mux (
    .clk_i,
    .rst_ni,
    .test_i(1'b0),
    .slv_reqs_i ({table_offset_req(root_table_base_addr_i, root_mem_req),
                  table_offset_req(leaf_table_base_addr_i, leaf_mem_req)}),
    .slv_resps_o({root_mem_resp, leaf_mem_resp}),
    .mst_req_o  (mem_req_o),
    .mst_resp_i (mem_resp_i)
  );

  //// debug
  //assign mem_req_o = leaf_mem_req;
  //assign leaf_mem_resp = mem_resp_i;

endmodule
