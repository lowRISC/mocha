// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   07.12.2023

/// [TODO] - Description goes here

module axi_tagctrl_top #(
    parameter int unsigned grouping_factor = 256,
    parameter int unsigned root_cache_ways = 4,
    parameter int unsigned root_cache_byte_size = 2048,
    parameter int unsigned leaf_cache_ways = 4,
    parameter int unsigned leaf_cache_byte_size = 16384,
    parameter int unsigned tagged_chunk_size = 16,
    parameter int unsigned covered_align = 4096,
    parameter int unsigned tag_store_align = 64,
    /// covered region base address on initialisation
    parameter int unsigned init_covered_base = 64'd0,
    /// covered region top address on initialisation
    parameter int unsigned init_covered_top = 64'd0,
    /// tag store base address on initialisation
    parameter int unsigned init_tag_table_base = 64'd0,
    /// start on reset (initial zeroing)
    parameter logic init_start = 1'b0,
    /// locked on reset (prevent dynamic configuration)
    parameter logic init_locked = 1'b1,
    /// allow resume without zeroing backing store
    parameter logic allow_resume = 1'b0,
    /// allow flush when locked
    parameter logic allow_flush_when_locked = 1'b0,
    /// how many perf counters (0 to disable completely)
    parameter int unsigned perf_counters = 0,
    /// Capability size in memory
    parameter int unsigned cap_size = 128,
    /// Maximum concurrent AXI transactions on both ports
    parameter int unsigned max_trans = 10,
    /// AXI4+ATOP ID field width of the slave port.
    /// The ID field width of the master port is this parameter + 1.
    parameter int unsigned axi_id_width = 32'd6,
    /// AXI4+ATOP address field width of both the slave and master port.
    parameter int unsigned axi_addr_width = 32'd64,
    /// AXI4+ATOP data field width of both the slave and the master port.
    parameter int unsigned axi_data_width = 32'd64,
    /// AXI4+ATOP user field width of both the slave and the master port.
    parameter int unsigned axi_user_width = 32'd1,
    /// AXI4+ATOP request type on the slave port.
    /// Expected format can be defined using `AXI_TYPEDEF_REQ_T.
    parameter type slv_req_t = logic,
    /// AXI4+ATOP response type on the slave port.
    /// Expected format can be defined using `AXI_TYPEDEF_RESP_T.
    parameter type slv_resp_t = logic,
    /// AXI4+ATOP request type on the master port.
    /// Expected format can be defined using `AXI_TYPEDEF_REQ_T.
    parameter type mst_req_t = logic,
    /// AXI4+ATOP response type on the master port.
    /// Expected format can be defined using `AXI_TYPEDEF_RESP_T.
    parameter type mst_resp_t = logic,
    /// Dependent parameter, do **not** overwrite!
    /// Address type of the AXI4+ATOP ports.
    /// The address fields of the rule type have to be the same.
    parameter type axi_addr_t = logic [axi_addr_width-1:0]
) (
    /// Rising-edge clock of all ports.
    input logic clk_i,
    /// Asynchronous reset, active low
    input logic rst_ni,
    /// Test mode activate, active high.
    input logic test_i,
    /// AXI4 slave port conf. request
    input slv_req_t config_sub_req_i,
    /// AXI4 slave port conf. response
    output slv_resp_t config_sub_resp_o,
    /// AXI4+ATOP slave port request, CPU side
    input slv_req_t tagged_sub_req_i,
    /// AXI4+ATOP slave port response, CPU side
    output slv_resp_t tagged_sub_resp_o,
    /// AXI4+ATOP master port request, memory side
    output mst_req_t untagged_mgr_req_o,
    /// AXI4+ATOP master port response, memory side
    input mst_resp_t untagged_mgr_resp_i
);
  `include "axi/typedef.svh"

  typedef logic [axi_id_width-1:0] axi_slv_id_t;
  typedef logic [axi_id_width:0] axi_mst_id_t;
  typedef logic [axi_data_width-1:0] axi_data_t;
  typedef logic [(axi_data_width/8)-1:0] axi_strb_t;
  typedef logic [axi_user_width-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(slv_aw_chan_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AW_CHAN_T(mst_aw_chan_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(slv_b_chan_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(mst_b_chan_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(slv_ar_chan_t, axi_addr_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(mst_ar_chan_t, axi_addr_t, axi_mst_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(slv_r_chan_t, axi_data_t, axi_slv_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(mst_r_chan_t, axi_data_t, axi_mst_id_t, axi_user_t)

  localparam axi_tagctrl_pkg::tagctrl_cfg_t Cfg = axi_tagctrl_pkg::tagctrl_cfg_t
'{
      AxiIdWidth: axi_id_width,
      AxiAddrWidth: axi_addr_width,
      AxiDataWidth: axi_data_width,
      CapSize: cap_size,
      TagWFifoDepth: 4,
      TagAXFifoDepth: 4,
      TagRFifoDepth: 32
  };

  typedef struct packed {
    // AXI4+ATOP specific descriptor signals
    axi_slv_id_t a_x_id;  // AXI ID from slave port
    axi_addr_t a_x_addr;  // memory address
    axi_pkg::len_t a_x_len;  // AXI burst length
    axi_pkg::size_t a_x_size;  // AXI burst size
    axi_pkg::burst_t a_x_burst;  // AXI burst type
    axi_pkg::resp_t x_resp;  // AXI response signal, for error propagation
    logic x_last;  // Last descriptor of a burst
    logic tagged_req;  // Request should interact with tags
    logic illegal_req;  // Request tries to directly access tags
  } desc_t;

  // struct to pass between the tag controller and the tag cache
  typedef struct packed {
    axi_data_t data;    // input data
    axi_data_t bit_en;  // write bit enable
    axi_strb_t strb;    // write enable (equals AXI strb)
  } tagc_oup_t;

  typedef struct packed {
    axi_slv_id_t    id;    // AXI id of the count operation
    axi_data_t      data;  // read data from the way
    axi_pkg::resp_t resp;
    logic           last;
    logic           aborted;
    logic           hit;
  } tagc_inp_t;

  // R tag bits payload between the tag cache and tag controller
  tagc_inp_t tagc_r_inp;
  logic tagc_r_inp_valid, tagc_r_inp_ready;

  // W tag bits payload between the tag controller and tag cache
  tagc_oup_t tagc_w_oup;
  logic tagc_w_oup_valid, tagc_w_oup_ready;
  slv_b_chan_t tagc_b_chan, tagc_b_chan_buff;
  logic tagc_b_chan_valid, tagc_b_chan_ready, tagc_b_chan_buff_valid, tagc_b_chan_buff_ready;

  // tag controller and tag cache connection to the memory
  slv_req_t to_tagctrl_req, tagctrl_req, tagc_req;
  slv_resp_t from_tagctrl_resp, tagctrl_resp, tagc_resp;

  // signals between channel splitters and rw_arb_tree
  desc_t [1:0] ax_desc;
  logic  [1:0] ax_desc_valid;
  logic  [1:0] ax_desc_ready;

  // descriptor from the tagctrl_ar to the ar FIFO
  desc_t tagctrl_ar_desc;
  logic tagctrl_ar_valid, tagctrl_ar_ready;

  // descriptor from the ar FIFO to the tagctrl_r unit
  desc_t tagctrl_r_desc;
  logic tagctrl_r_valid, tagctrl_r_ready;

  // descriptor from the tagctrl_aw to the aw FIFO
  desc_t tagctrl_aw_desc;
  logic tagctrl_aw_valid, tagctrl_aw_ready;

  // descriptor from the aw FIFO to the tagctrl_w unit
  desc_t tagctrl_w_desc;
  logic tagctrl_w_valid, tagctrl_w_ready;

  // configuration signals
  axi_addr_t covered_base_addr, covered_top_addr;
  axi_addr_t tag_store_base_addr, tag_store_top_addr;
  axi_addr_t root_table_base_addr, root_table_top_addr;
  axi_addr_t leaf_table_base_addr, leaf_table_top_addr;

  // orchestration signals
  logic isolate;
  logic isolated;
  logic ignore_tags;
  logic perform_zeroing;
  logic done_zeroing;
  logic perform_flushing;
  logic done_flushing;

  // performance events
  axi_tagctrl_pkg::tagctrl_events_t events;

  // configuration module
  axi_tagctrl_config #(
    .GROUPING_FACTOR(grouping_factor),
    .TAGGED_CHUNK_SIZE(tagged_chunk_size),
    .COVERED_ALIGN(covered_align),
    .TAG_STORE_ALIGN(tag_store_align),
    .slv_req_t(slv_req_t),
    .slv_resp_t(slv_resp_t),
    .ar_chan_t (slv_ar_chan_t),
    .r_chan_t (slv_r_chan_t),
    .aw_chan_t (slv_aw_chan_t),
    .w_chan_t (w_chan_t),
    .b_chan_t (slv_b_chan_t),
    .axi_addr_t(axi_addr_t),
    .init_covered_base(init_covered_base),
    .init_covered_top(init_covered_top),
    .init_tag_table_base(init_tag_table_base),
    .init_start(init_start),
    .init_locked(init_locked),
    .allow_resume(allow_resume),
    .allow_flush_when_locked(allow_flush_when_locked),
    .perf_counters(perf_counters)
  ) i_axi_tagctrl_config (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .slv_req_i(config_sub_req_i),
    .slv_resp_o(config_sub_resp_o),

    // signaling
    .isolate_o(isolate),
    .isolated_i(isolated),
    .ignore_tags_o(ignore_tags),
    .perform_zeroing_o(perform_zeroing),
    .done_zeroing_i(done_zeroing),
    .perform_flushing_o(perform_flushing),
    .done_flushing_i(done_flushing),

    // reporting
    .covered_base_addr_o(covered_base_addr),
    .covered_top_addr_o(covered_top_addr),
    .tag_store_base_addr_o(tag_store_base_addr),
    .tag_store_top_addr_o(tag_store_top_addr),
    .root_table_base_addr_o(root_table_base_addr),
    .root_table_top_addr_o(root_table_top_addr),
    .leaf_table_base_addr_o(leaf_table_base_addr),
    .leaf_table_top_addr_o(leaf_table_top_addr),
    .error_o(/*TODO*/),

    .events_o(events.config_events),
    .events_i(events)
  );

  // backing tag memory accesses
  tag_lookup_engine #(
    .tag_req_t(desc_t),
    .tag_data_req_t(tagc_oup_t),
    .tag_write_resp_t(slv_b_chan_t),
    .tag_read_resp_t(tagc_inp_t),
    .AxiMstIdWidth(axi_id_width),
    .AxiAddrWidth(axi_addr_width),
    .AxiDataWidth(axi_data_width),
    .AxiUserWidth(axi_user_width),
    .mem_req_t(slv_req_t),
    .mem_resp_t(slv_resp_t),
    .axi_addr_t(axi_addr_t),
    .GROUPING_FACTOR(grouping_factor),
    .ROOT_CACHE_WAYS(root_cache_ways),
    .ROOT_CACHE_BYTE_SIZE(root_cache_byte_size),
    .LEAF_CACHE_WAYS(leaf_cache_ways),
    .LEAF_CACHE_BYTE_SIZE(leaf_cache_byte_size)
  ) i_tag_lookup_engine (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    // tag store configuration
    .root_table_base_addr_i(root_table_base_addr),
    .root_table_top_addr_i(root_table_top_addr),
    .leaf_table_base_addr_i(leaf_table_base_addr),
    .leaf_table_top_addr_i(leaf_table_top_addr),
    // command and reporting signals
    .perform_zeroing_i(perform_zeroing),
    .done_zeroing_o(done_zeroing),
    .perform_flushing_i(perform_flushing),
    .done_flushing_o(done_flushing),
    // incoming read tag request descriptor
    .read_req_valid_i(ax_desc_valid[0]),
    .read_req_ready_o(ax_desc_ready[0]),
    .read_req_i(ax_desc[0]),
    // outgoing read response
    .read_resp_valid_o(tagc_r_inp_valid),
    .read_resp_ready_i(tagc_r_inp_ready),
    .read_resp_o(tagc_r_inp),
    // incoming write tag request descriptor
    .write_req_valid_i(ax_desc_valid[1]),
    .write_req_ready_o(ax_desc_ready[1]),
    .write_req_i(ax_desc[1]),
    // incoming write data
    .write_data_req_valid_i(tagc_w_oup_valid),
    .write_data_req_ready_o(tagc_w_oup_ready),
    .write_data_req_i(tagc_w_oup),
    // outgoing write response
    .write_resp_valid_o(tagc_b_chan_valid),
    .write_resp_ready_i(tagc_b_chan_ready),
    .write_resp_o(tagc_b_chan),
    // tag store memory interfaces
    .mem_req_o(tagc_req),
    .mem_resp_i(tagc_resp),
    // performance events
    .events_o(events.lookup_engine_events)
  );

  //--------------------------------//
  // Tag controller R channel Logic //
  //--------------------------------//

  axi_tagctrl_ax #(
      .Cfg       (Cfg),
      .desc_t    (desc_t),
      .ax_chan_t (slv_ar_chan_t),
      .axi_addr_t(axi_addr_t)
  ) axi_tag_ctrl_ar (
      .clk_i,
      .rst_ni,
      .ignore_tags_i         (ignore_tags),
      .covered_base_addr_i   (covered_base_addr),
      .covered_top_addr_i    (covered_top_addr),
      .tag_store_base_addr_i (tag_store_base_addr),
      .tag_store_top_addr_i  (tag_store_top_addr),
      .ax_chan_slv_i         (to_tagctrl_req.ar),
      .ax_chan_valid_i       (to_tagctrl_req.ar_valid),
      .ax_chan_ready_o       (from_tagctrl_resp.ar_ready),
      .tagc_desc_o           (ax_desc[0]),
      .tagc_valid_o          (ax_desc_valid[0]),
      .tagc_ready_i          (ax_desc_ready[0]),
      .ax_mem_chan_mst_o     (tagctrl_req.ar),
      .ax_mem_chan_valid_o   (tagctrl_req.ar_valid),
      .ax_mem_chan_ready_i   (tagctrl_resp.ar_ready),
      .tagctrl_desc_o        (tagctrl_ar_desc),
      .tagctrl_valid_o       (tagctrl_ar_valid),
      .tagctrl_ready_i       (tagctrl_ar_ready)
  );

  // FIFO between AR master and R master, there can be DEPTH inflight transactions
  stream_fifo #(
      .FALL_THROUGH(1'b1),
      .DEPTH       (Cfg.TagAXFifoDepth),
      .T           (desc_t)
  ) i_stream_fifo_r (
      .clk_i,
      .rst_ni,
      .flush_i   (1'b0),
      .testmode_i(test_i),
      .usage_o   (  /*not used*/),
      .data_i    (tagctrl_ar_desc),
      .valid_i   (tagctrl_ar_valid),
      .ready_o   (tagctrl_ar_ready),
      .data_o    (tagctrl_r_desc),
      .valid_o   (tagctrl_r_valid),
      .ready_i   (tagctrl_r_ready)
  );

  axi_tagctrl_r #(
      .Cfg           (Cfg),
      .desc_t        (desc_t),
      .tagc_inp_t    (tagc_inp_t),
      .r_chan_t      (slv_r_chan_t)
  ) i_axi_tag_ctrl_r (
      .clk_i,
      .rst_ni,
      .tagctrl_desc_i      (tagctrl_r_desc),
      .tagctrl_desc_valid_i(tagctrl_r_valid),
      .tagctrl_desc_ready_o(tagctrl_r_ready),
      .r_chan_mst_i        (tagctrl_resp.r),
      .r_chan_valid_i      (tagctrl_resp.r_valid),
      .r_chan_ready_o      (tagctrl_req.r_ready),
      .tagc_inp_r_i        (tagc_r_inp),
      .tagc_inp_r_valid_i  (tagc_r_inp_valid),
      .tagc_inp_r_ready_o  (tagc_r_inp_ready),
      .r_chan_slv_o        (from_tagctrl_resp.r),
      .r_chan_slv_valid_o  (from_tagctrl_resp.r_valid),
      .r_chan_slv_ready_i  (to_tagctrl_req.r_ready)
  );

  //--------------------------------//
  // Tag controller W channel Logic //
  //--------------------------------//

  axi_tagctrl_ax #(
      .Cfg       (Cfg),
      .desc_t    (desc_t),
      .ax_chan_t (slv_aw_chan_t),
      .axi_addr_t(axi_addr_t)
  ) axi_tag_ctrl_aw (
      .clk_i,
      .rst_ni,
      .ignore_tags_i         (ignore_tags),
      .covered_base_addr_i   (covered_base_addr),
      .covered_top_addr_i    (covered_top_addr),
      .tag_store_base_addr_i (tag_store_base_addr),
      .tag_store_top_addr_i  (tag_store_top_addr),
      .ax_chan_slv_i         (to_tagctrl_req.aw),
      .ax_chan_valid_i       (to_tagctrl_req.aw_valid),
      .ax_chan_ready_o       (from_tagctrl_resp.aw_ready),
      .tagc_desc_o           (ax_desc[1]),
      .tagc_valid_o          (ax_desc_valid[1]),
      .tagc_ready_i          (ax_desc_ready[1]),
      .ax_mem_chan_mst_o     (tagctrl_req.aw),
      .ax_mem_chan_valid_o   (tagctrl_req.aw_valid),
      .ax_mem_chan_ready_i   (tagctrl_resp.aw_ready),
      .tagctrl_desc_o        (tagctrl_aw_desc),
      .tagctrl_valid_o       (tagctrl_aw_valid),
      .tagctrl_ready_i       (tagctrl_aw_ready)
  );

  // FIFO between AW master and W master, there can be DEPTH inflight transactions
  stream_fifo #(
      .FALL_THROUGH(1'b1),
      .DEPTH       (Cfg.TagWFifoDepth),
      .T           (desc_t)
  ) i_stream_fifo_w (
      .clk_i,
      .rst_ni,
      .flush_i   (1'b0),
      .testmode_i(test_i),
      .usage_o   (  /*not used*/),
      .data_i    (tagctrl_aw_desc),
      .valid_i   (tagctrl_aw_valid),
      .ready_o   (tagctrl_aw_ready),
      .data_o    (tagctrl_w_desc),
      .valid_o   (tagctrl_w_valid),
      .ready_i   (tagctrl_w_ready)
  );

  // FIFO between tag B slave and tagctrl B master
  stream_fifo #(
      .FALL_THROUGH(1'b1),
      .DEPTH       (Cfg.TagWFifoDepth),
      .T           (slv_b_chan_t)
  ) i_stream_fifo_tagc_b (
      .clk_i,
      .rst_ni,
      .flush_i   (1'b0),
      .testmode_i(test_i),
      .usage_o   (  /*not used*/),
      .data_i    (tagc_b_chan),
      .valid_i   (tagc_b_chan_valid),
      .ready_o   (tagc_b_chan_ready), // This one is possibly ignored, which is why we have this buffer.
      .data_o    (tagc_b_chan_buff),
      .valid_o   (tagc_b_chan_buff_valid),
      .ready_i   (tagc_b_chan_buff_ready)
  );

  axi_tagctrl_w #(
      .Cfg           (Cfg),
      .desc_t        (desc_t),
      .tagc_oup_t    (tagc_oup_t),
      .w_chan_t      (w_chan_t),
      .b_chan_t      (slv_b_chan_t)
  ) i_axi_tag_ctrl_w (
      .clk_i,
      .rst_ni,
      .test_i,
      .tagctrl_desc_i      (tagctrl_w_desc),
      .tagctrl_desc_valid_i(tagctrl_w_valid),
      .tagctrl_desc_ready_o(tagctrl_w_ready),
      .w_chan_slv_i        (to_tagctrl_req.w),
      .w_chan_slv_valid_i  (to_tagctrl_req.w_valid),
      .w_chan_slv_ready_o  (from_tagctrl_resp.w_ready),
      .b_chan_slv_o        (from_tagctrl_resp.b),
      .b_chan_slv_valid_o  (from_tagctrl_resp.b_valid),
      .b_chan_slv_ready_i  (to_tagctrl_req.b_ready),
      .tagc_oup_o          (tagc_w_oup),
      .tagc_oup_valid_o    (tagc_w_oup_valid),
      .tagc_oup_ready_i    (tagc_w_oup_ready),
      .tagc_resp_i         (tagc_b_chan_buff),
      .tagc_resp_valid_i   (tagc_b_chan_buff_valid),
      .tagc_resp_ready_o   (tagc_b_chan_buff_ready),
      .w_chan_mst_o        (tagctrl_req.w),
      .w_chan_mst_valid_o  (tagctrl_req.w_valid),
      .w_chan_mst_ready_i  (tagctrl_resp.w_ready),
      .b_chan_mst_i        (tagctrl_resp.b),
      .b_chan_mst_valid_i  (tagctrl_resp.b_valid),
      .b_chan_mst_ready_o  (tagctrl_req.b_ready)
  );

  // AXI Mux to multiplex accesses from the tag cache to refill/evict tag cache lines
  // and from the tracker to read/write to memory
  // Attention: This unit widens the AXI ID by one!
  axi_mux #(
      .SlvAxiIDWidth(axi_id_width),
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
      .mst_req_t    (mst_req_t),
      .mst_resp_t   (mst_resp_t),
      .NoSlvPorts   (32'd2),
      .MaxWTrans    (max_trans),
      .FallThrough  (1'b0),                   // No registers
      .SpillAw      (1'b0),                   // No registers
      .SpillW       (1'b0),                   // No registers
      .SpillB       (1'b0),                   // No registers
      .SpillAr      (1'b0),                   // No registers
      .SpillR       (1'b0)                    // No registers
  ) i_axi_mux (
      .clk_i      (clk_i),
      .rst_ni     (rst_ni),
      .test_i     (test_i),
      .slv_reqs_i ({tagc_req, tagctrl_req}),
      .slv_resps_o({tagc_resp, tagctrl_resp}),
      .mst_req_o  (untagged_mgr_req_o),
      .mst_resp_i (untagged_mgr_resp_i)
  );

  slv_req_t  slv_req_cut;
  slv_resp_t slv_resp_cut;

  axi_cut #(
      // AXI channel structs
      .aw_chan_t (slv_aw_chan_t),
      .w_chan_t  (w_chan_t),
      .b_chan_t  (slv_b_chan_t),
      .ar_chan_t (slv_ar_chan_t),
      .r_chan_t  (slv_r_chan_t),
      .axi_req_t (slv_req_t),
      .axi_resp_t(slv_resp_t)
  ) i_axi_cut (
      .clk_i,
      .rst_ni,
      .slv_req_i (tagged_sub_req_i),
      .slv_resp_o(tagged_sub_resp_o),
      .mst_req_o (slv_req_cut),
      .mst_resp_i(slv_resp_cut)
  );

  axi_isolate #(
      .NumPending (max_trans),
      .AxiAddrWidth(axi_addr_width),
      .AxiDataWidth(axi_data_width),
      .AxiIdWidth  (axi_id_width),
      .AxiUserWidth(axi_user_width),
      .axi_req_t   (slv_req_t),
      .axi_resp_t  (slv_resp_t)
  ) i_axi_isolate_flush (
      .clk_i,
      .rst_ni,
      .slv_req_i  (slv_req_cut),  // Slave port request
      .slv_resp_o (slv_resp_cut), // Slave port response
      .mst_req_o  (to_tagctrl_req),
      .mst_resp_i (from_tagctrl_resp),
      .isolate_i  (isolate),
      .isolated_o (isolated)
  );

  // pragma translate_off
  initial begin : proc_assert_axi_params
    assert_axi_addr_width :
    assert (axi_addr_width > 32'd0)
    else $fatal(1, "Parameter `axi_addr_width` has to be > 0!");
    assert_axi_id_width :
    assert (axi_id_width > 32'd0)
    else $fatal(1, "Parameter `axi_id_width` has to be > 0!");
    assert_axi_data_width :
    assert(axi_data_width inside {32'd8, 32'd16, 32'd32, 32'd64,
                                                 32'd128, 32'd256, 32'd512, 32'd1028})
    else $fatal(1, "Parameter `axi_data_width` has to be inside the AXI4+ATOP specification!");
    assert_axi_user_width :
    assert (axi_user_width > 32'd0)
    else $fatal(1, "Parameter `axi_user_width` has to be > 0!");

    // check the structs against the Cfg
    assert_slv_aw_id :
    assert ($bits(tagged_sub_req_i.aw.id) == axi_id_width)
    else $fatal(1, $sformatf("llc> AXI Slave port, AW ID width not equal to axi_id_width"));
    assert_slv_aw_addr :
    assert ($bits(tagged_sub_req_i.aw.addr) == axi_addr_width)
    else $fatal(1, $sformatf("llc> AXI Slave port, AW ADDR width not equal to axi_addr_width"));
    assert_slv_ar_id :
    assert ($bits(tagged_sub_req_i.ar.id) == axi_id_width)
    else $fatal(1, $sformatf("llc> AXI Slave port, AR ID width not equal to axi_id_width"));
    assert_slv_ar_addr :
    assert ($bits(tagged_sub_req_i.ar.addr) == axi_addr_width)
    else $fatal(1, $sformatf("llc> AXI Slave port, AR ADDR width not equal to axi_addr_width"));
    assert_slv_w_data :
    assert ($bits(tagged_sub_req_i.w.data) == axi_data_width)
    else $fatal(1, $sformatf("llc> AXI Slave port, W DATA width not equal to axi_data_width"));
    assert_slv_r_data :
    assert ($bits(tagged_sub_resp_o.r.data) == axi_data_width)
    else $fatal(1, $sformatf("llc> AXI Slave port, R DATA width not equal to axi_data_width"));
    // compare the types against the structs
    assert_slv_req_aw :
    assert ($bits(slv_aw_chan_t) == $bits(tagged_sub_req_i.aw))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_aw_chan_t and tagged_sub_req_i.aw not equal"));
    assert_slv_req_w :
    assert ($bits(w_chan_t) == $bits(tagged_sub_req_i.w))
    else $fatal(1, $sformatf("llc> AXI Slave port, w_chan_t and tagged_sub_req_i.w not equal"));
    assert_slv_req_b :
    assert ($bits(slv_b_chan_t) == $bits(tagged_sub_resp_o.b))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_b_chan_t and tagged_sub_resp_o.b not equal"));
    assert_slv_req_ar :
    assert ($bits(slv_ar_chan_t) == $bits(tagged_sub_req_i.ar))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_ar_chan_t and tagged_sub_req_i.ar not equal"));
    assert_slv_req_r :
    assert ($bits(slv_r_chan_t) == $bits(tagged_sub_resp_o.r))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_r_chan_t and tagged_sub_resp_o.r not equal"));
    // check the structs against the Cfg
    assert_mst_aw_id :
    assert ($bits(untagged_mgr_req_o.aw.id) == axi_id_width + 1)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ID not equal to axi_id_width + 1"));
    assert_mst_aw_addr :
    assert ($bits(untagged_mgr_req_o.aw.addr) == axi_addr_width)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ADDR width not equal to axi_addr_width"));
    assert_mst_ar_id :
    assert ($bits(untagged_mgr_req_o.ar.id) == axi_id_width + 1)
    else $fatal(1, $sformatf("llc> AXI Master port, AW ID not equal to axi_id_width + 1"));
    assert_mst_ar_addr :
    assert ($bits(untagged_mgr_req_o.ar.addr) == axi_addr_width)
    else $fatal(1, $sformatf("llc> AXI Master port, AR ADDR width not equal to axi_addr_width"));
    assert_mst_w_data :
    assert ($bits(untagged_mgr_req_o.w.data) == axi_data_width)
    else $fatal(1, $sformatf("llc> AXI Master port, W DATA width not equal to axi_data_width"));
    assert_mst_r_data :
    assert ($bits(untagged_mgr_resp_i.r.data) == axi_data_width)
    else $fatal(1, $sformatf("llc> AXI Master port, R DATA width not equal to axi_data_width"));
    // compare the types against the structs
    assert_mst_req_aw :
    assert ($bits(mst_aw_chan_t) == $bits(untagged_mgr_req_o.aw))
    else $fatal(1, $sformatf("llc> AXI Master port, mst_aw_chan_t and untagged_mgr_req_o.aw not equal"));
    assert_mst_req_w :
    assert ($bits(w_chan_t) == $bits(untagged_mgr_req_o.w))
    else $fatal(1, $sformatf("llc> AXI Master port, w_chan_t and untagged_mgr_req_o.w not equal"));
    assert_mst_req_b :
    assert ($bits(mst_b_chan_t) == $bits(untagged_mgr_resp_i.b))
    else $fatal(1, $sformatf("llc> AXI Master port, mst_b_chan_t and untagged_mgr_resp_i.b not equal"));
    assert_mst_req_ar :
    assert ($bits(mst_ar_chan_t) == $bits(untagged_mgr_req_o.ar))
    else $fatal(1, $sformatf("llc> AXI Master port, mst_ar_chan_t and untagged_mgr_req_i.ar not equal"));
    assert_mst_req_r :
    assert ($bits(mst_r_chan_t) == $bits(untagged_mgr_resp_i.r))
    else $fatal(1, $sformatf("llc> AXI Slave port, slv_r_chan_t and untagged_mgr_resp_i.r not equal"));
  end
  // pragma translate_on

endmodule
