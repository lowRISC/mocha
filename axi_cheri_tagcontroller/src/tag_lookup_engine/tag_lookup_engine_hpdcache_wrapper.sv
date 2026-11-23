// TODO header

`include "hpdcache_typedef.svh"
`include "axi/typedef.svh"

module hpdcache_wrapper #(
    parameter type tag_req_t = logic,
    parameter type tag_data_req_t = logic,
    parameter type tag_write_resp_t = logic,
    parameter type tag_read_resp_t = logic,
    parameter int unsigned nReadPorts = 64'd2,
    parameter int unsigned nWritePorts = 64'd1,
    parameter int unsigned AxiIdWidth = 64'd6,
    parameter int unsigned AxiAddrWidth = 64'd64,
    parameter int unsigned AxiDataWidth = 64'd64,
    parameter int unsigned AxiUserWidth = 64'd1,
    parameter type mem_req_t = logic,
    parameter type mem_resp_t = logic,
    parameter type axi_addr_t = logic [AxiAddrWidth-1:0],
    parameter hpdcache_pkg::hpdcache_user_cfg_t HPDcacheUserCfg = 0
  ) (
    // Rising-edge clock of all ports.
    input logic clk_i,
    // Asynchronous reset, active low
    input logic rst_ni,

    // tag controller slave interfaces //
    /////////////////////////////////////
    // incoming tag read request descriptor
    input logic read_req_speculative_i[nReadPorts],
    input logic read_req_valid_i[nReadPorts],
    output logic read_req_ready_o[nReadPorts],
    input tag_req_t read_req_i[nReadPorts],
    // incoming tag write request descriptor
    input logic write_req_valid_i[nWritePorts],
    output logic write_req_ready_o[nWritePorts],
    input tag_req_t write_req_i[nWritePorts],
    input logic write_req_flush_i[nWritePorts],
    // incoming write data
    input logic write_data_req_valid_i[nWritePorts],
    output logic write_data_req_ready_o[nWritePorts],
    input tag_data_req_t write_data_req_i[nWritePorts],
    // outgoing write response
    output logic write_resp_valid_o[nWritePorts],
    input logic write_resp_ready_i[nWritePorts],
    output tag_write_resp_t write_resp_o[nWritePorts],
    // outgoing read response
    output logic read_resp_valid_o[nReadPorts],
    input logic read_resp_ready_i[nReadPorts],
    output tag_read_resp_t read_resp_o[nReadPorts],

    // cache events //
    /////////////////////////////////////
    output axi_tagctrl_pkg::hpdcache_events_t events_o,

    // tag store master interfaces //
    /////////////////////////////////
    output mem_req_t mem_req_o,
    input mem_resp_t mem_resp_i
  );

  // configurations and types
  //////////////////////////////////////////////////////////////////////////////
  localparam hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = hpdcache_pkg::hpdcacheBuildConfig(
      HPDcacheUserCfg
  );
  //      Request Interface Definitions
  //      {{{
  localparam type wbuf_timecnt_t = logic unsigned [HPDcacheCfg.u.wbufTimecntWidth-1:0];
  localparam type hpdcache_tag_t = logic [HPDcacheCfg.tagWidth-1:0];
  localparam type hpdcache_pma_t = hpdcache_pkg::hpdcache_pma_t;
  localparam type hpdcache_data_word_t = logic [HPDcacheCfg.u.wordWidth-1:0];
  localparam type hpdcache_data_be_t = logic [(HPDcacheCfg.u.wordWidth+8-1)/8-1:0];
  localparam type hpdcache_req_offset_t = logic [HPDcacheCfg.reqOffsetWidth-1:0];
  localparam type hpdcache_req_data_t = hpdcache_data_word_t [HPDcacheCfg.u.reqWords-1:0];
  localparam type hpdcache_req_be_t = hpdcache_data_be_t [HPDcacheCfg.u.reqWords-1:0];
  localparam type hpdcache_req_sid_t = logic [HPDcacheCfg.u.reqSrcIdWidth-1:0];
  localparam type hpdcache_req_tid_t = logic [HPDcacheCfg.u.reqTransIdWidth-1:0];
  localparam type hpdcache_req_t =
          `HPDCACHE_DECL_REQ_T(
                  hpdcache_req_offset_t,
                  hpdcache_req_data_t,
                  hpdcache_req_be_t,
                  hpdcache_req_sid_t,
                  hpdcache_req_tid_t,
                  hpdcache_tag_t);
  localparam type hpdcache_rsp_t =
          `HPDCACHE_DECL_RSP_T(
                  hpdcache_req_data_t,
                  hpdcache_req_sid_t,
                  hpdcache_req_tid_t);
  localparam type hpdcache_mem_addr_t   = logic [HPDcacheCfg.u.memAddrWidth-1:0];
  localparam type hpdcache_mem_id_t     = logic [HPDcacheCfg.u.memIdWidth-1:0];
  localparam type hpdcache_mem_data_t   = logic [HPDcacheCfg.u.memDataWidth-1:0];
  localparam type hpdcache_mem_bit_en_t = logic [HPDcacheCfg.u.memDataWidth-1:0];
  localparam type hpdcache_mem_be_t     = logic [HPDcacheCfg.u.memDataWidth/8-1:0];

  //  Declaration of internal types
  //  {{{
  `HPDCACHE_TYPEDEF_MEM_REQ_T(hpdcache_mem_req_t, hpdcache_mem_addr_t, hpdcache_mem_id_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_R_T(hpdcache_mem_resp_r_t, hpdcache_mem_id_t, hpdcache_mem_data_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_bit_w_t, hpdcache_mem_data_t, hpdcache_mem_bit_en_t);
  `HPDCACHE_TYPEDEF_MEM_REQ_W_T(hpdcache_mem_req_w_t, hpdcache_mem_data_t, hpdcache_mem_be_t);
  `HPDCACHE_TYPEDEF_MEM_RESP_W_T(hpdcache_mem_resp_w_t, hpdcache_mem_id_t);
  //  }}}

  // hpdcache <-> mem converters
  //////////////////////////////////////////////////////////////////////////////
  /////////////////////////////
  // Axi channel definitions //
  /////////////////////////////
  localparam int unsigned AxiStrbWidth = AxiDataWidth / 32'd8;
  typedef logic [AxiIdWidth-1:0] axi_id_t;
  typedef logic [AxiDataWidth-1:0] axi_data_t;
  typedef logic [AxiStrbWidth-1:0] axi_strb_t;
  typedef logic [AxiUserWidth-1:0] axi_user_t;
  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_b_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_t, axi_data_t, axi_id_t, axi_user_t)

  logic mem_req_read_ready;
  logic mem_req_read_valid;
  hpdcache_mem_req_t mem_req_read;
  logic mem_resp_read_ready;
  logic mem_resp_read_valid;
  hpdcache_mem_resp_r_t mem_resp_read;
  logic mem_req_write_ready;
  logic mem_req_write_valid;
  hpdcache_mem_req_t mem_req_write;
  logic mem_req_write_data_ready;
  logic mem_req_write_data_valid;
  hpdcache_mem_req_bit_w_t mem_req_write_data;
  logic mem_resp_write_ready;
  logic mem_resp_write_valid;
  hpdcache_mem_resp_w_t mem_resp_write;

  function automatic hpdcache_mem_req_t mem_req_bit_2_byte(hpdcache_mem_req_t req);
    hpdcache_mem_req_t ret = req;
    ret.mem_req_addr = req.mem_req_addr >> 3;
    ret.mem_req_size = req.mem_req_size - 3;
    return ret;
  endfunction

  function automatic hpdcache_mem_req_w_t mem_req_w_bit_2_byte(hpdcache_mem_req_bit_w_t req);
    hpdcache_mem_req_w_t ret;
    localparam int unsigned ratio = $bits(req.mem_req_w_be) / $bits(ret.mem_req_w_be);
    for (int unsigned i = 0; i < ratio; i++) begin
      assert (^(req.mem_req_w_be[i*ratio +: ratio]) == 0) else begin
        $display("TagController HPDCache must produce bit enables that can be expressed as byte enables. %x", req.mem_req_w_be);
        $error("Exiting.");
      end
      ret.mem_req_w_be[i] = req.mem_req_w_be[i*ratio];
    end
    ret.mem_req_w_data = req.mem_req_w_data;
    ret.mem_req_w_last = req.mem_req_w_last;
    ret.mem_req_w_user = req.mem_req_w_user;
    return ret;
  endfunction

  hpdcache_mem_to_axi_read #(
    .hpdcache_mem_req_t(hpdcache_mem_req_t),
    .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
    .ar_chan_t(axi_ar_t),
    .r_chan_t(axi_r_t)
  ) i_hpdcache_mem_to_axi_read (
    .req_ready_o(mem_req_read_ready),
    .req_valid_i(mem_req_read_valid),
    .req_i(mem_req_bit_2_byte(mem_req_read)),
    .resp_ready_i(mem_resp_read_ready),
    .resp_valid_o(mem_resp_read_valid),
    .resp_o(mem_resp_read),
    .axi_ar_valid_o(mem_req_o.ar_valid),
    .axi_ar_o(mem_req_o.ar),
    .axi_ar_ready_i(mem_resp_i.ar_ready),
    .axi_r_valid_i(mem_resp_i.r_valid),
    .axi_r_i(mem_resp_i.r),
    .axi_r_ready_o(mem_req_o.r_ready)
  );
  hpdcache_mem_to_axi_write #(
    .hpdcache_mem_req_t   (hpdcache_mem_req_t),
    .hpdcache_mem_req_w_t (hpdcache_mem_req_w_t),
    .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t),
    .aw_chan_t(axi_aw_t),
    .w_chan_t(axi_w_t),
    .b_chan_t(axi_b_t)
  ) i_hpdcache_mem_to_axi_write (
    .req_ready_o(mem_req_write_ready),
    .req_valid_i(mem_req_write_valid),
    .req_i(mem_req_bit_2_byte(mem_req_write)),
    .req_data_ready_o(mem_req_write_data_ready),
    .req_data_valid_i(mem_req_write_data_valid),
    .req_data_i(mem_req_w_bit_2_byte(mem_req_write_data)),
    .resp_ready_i(mem_resp_write_ready),
    .resp_valid_o(mem_resp_write_valid),
    .resp_o(mem_resp_write),
    .axi_aw_valid_o(mem_req_o.aw_valid),
    .axi_aw_o(mem_req_o.aw),
    .axi_aw_ready_i(mem_resp_i.aw_ready),
    .axi_w_valid_o(mem_req_o.w_valid),
    .axi_w_o(mem_req_o.w),
    .axi_w_ready_i(mem_resp_i.w_ready),
    .axi_b_valid_i(mem_resp_i.b_valid),
    .axi_b_i(mem_resp_i.b),
    .axi_b_ready_o(mem_req_o.b_ready)
  );

  // tag controller <-> hpdcache converters
  //////////////////////////////////////////////////////////////////////////////
  // connect to the internal hpdcache instance
  //////////////////////////////////////////////////////////////////////////////

  // cache requestors req and resp
  // reqs...
  logic cache_req_valid [HPDcacheCfg.u.nRequesters];
  logic cache_req_ready [HPDcacheCfg.u.nRequesters];
  hpdcache_req_t cache_req [HPDcacheCfg.u.nRequesters];
  logic cache_req_abort [HPDcacheCfg.u.nRequesters];
  hpdcache_tag_t cache_req_tag [HPDcacheCfg.u.nRequesters];
  hpdcache_pma_t cache_req_pma [HPDcacheCfg.u.nRequesters];
  // resps...
  logic cache_rsp_valid [HPDcacheCfg.u.nRequesters];
  hpdcache_rsp_t cache_rsp [HPDcacheCfg.u.nRequesters];

  // read requestors
  genvar readPortIdx;
  generate
    for (readPortIdx = 0; readPortIdx < nReadPorts; readPortIdx++) begin : gen_read_ports
      hpdcache_read_req_rsp_wrapper #(
        .HPDcacheCfg(HPDcacheCfg),
        .tag_req_t(tag_req_t),
        .tag_read_resp_t(tag_read_resp_t),
        .hpdcache_req_t(hpdcache_req_t),
        .hpdcache_rsp_t(hpdcache_rsp_t),
        .hpdcache_tag_t(hpdcache_tag_t),
        .hpdcache_pma_t(hpdcache_pma_t)
      ) read_wrapper_i (
        .clk_i, .rst_ni,
        .sid_i(hpdcache_req_sid_t'(readPortIdx)),
        .read_req_speculative_i(read_req_speculative_i[readPortIdx]),
        .read_req_valid_i(read_req_valid_i[readPortIdx]),
        .read_req_ready_o(read_req_ready_o[readPortIdx]),
        .read_req_i(read_req_i[readPortIdx]),
        .hpdcache_read_req_valid_o(cache_req_valid[readPortIdx]),
        .hpdcache_read_req_ready_i(cache_req_ready[readPortIdx]),
        .hpdcache_read_req_o(cache_req[readPortIdx]),
        .hpdcache_read_req_abort_o(cache_req_abort[readPortIdx]),
        .hpdcache_read_req_tag_o(cache_req_tag[readPortIdx]),
        .hpdcache_read_req_pma_o(cache_req_pma[readPortIdx]),
        .read_resp_valid_o(read_resp_valid_o[readPortIdx]),
        .read_resp_o(read_resp_o[readPortIdx]),
        .hpdcache_read_resp_valid_i(cache_rsp_valid[readPortIdx]),
        .hpdcache_read_resp_i(cache_rsp[readPortIdx])
      );
    end
  endgenerate

  // write requestors
  genvar writePortIdx;
  generate
    for (writePortIdx = 0; writePortIdx < nWritePorts; writePortIdx++) begin : gen_write_ports
      hpdcache_write_req_rsp_wrapper #(
        .HPDcacheCfg(HPDcacheCfg),
        .tag_req_t(tag_req_t),
        .tag_data_req_t(tag_data_req_t),
        .tag_write_resp_t(tag_write_resp_t),
        .hpdcache_req_t(hpdcache_req_t),
        .hpdcache_rsp_t(hpdcache_rsp_t)
      ) write_wrapper_i (
        .clk_i, .rst_ni,
        .sid_i(hpdcache_req_sid_t'(nReadPorts+writePortIdx)),
        .write_req_valid_i(write_req_valid_i[writePortIdx]),
        .write_req_ready_o(write_req_ready_o[writePortIdx]),
        .write_req_i(write_req_i[writePortIdx]),
        .write_req_flush_i(write_req_flush_i[writePortIdx]),
        .write_data_req_valid_i(write_data_req_valid_i[writePortIdx]),
        .write_data_req_ready_o(write_data_req_ready_o[writePortIdx]),
        .write_data_req_i(write_data_req_i[writePortIdx]),
        .hpdcache_write_req_valid_o(cache_req_valid[nReadPorts+writePortIdx]),
        .hpdcache_write_req_ready_i(cache_req_ready[nReadPorts+writePortIdx]),
        .hpdcache_write_req_o(cache_req[nReadPorts+writePortIdx]),
        .write_resp_valid_o(write_resp_valid_o[writePortIdx]),
        .write_resp_o(write_resp_o[writePortIdx]),
        .hpdcache_write_resp_valid_i(cache_rsp_valid[nReadPorts+writePortIdx]),
        .hpdcache_write_resp_i(cache_rsp[nReadPorts+writePortIdx])
      );
    end
  endgenerate

  // internal hpdcache instance
  //////////////////////////////////////////////////////////////////////////////

  hpdcache #(
      .HPDcacheCfg          (HPDcacheCfg),
      .wbuf_timecnt_t       (wbuf_timecnt_t),
      .hpdcache_tag_t       (hpdcache_tag_t),
      .hpdcache_data_word_t (hpdcache_data_word_t),
      .hpdcache_data_be_t   (hpdcache_data_be_t),
      .hpdcache_req_offset_t(hpdcache_req_offset_t),
      .hpdcache_req_data_t  (hpdcache_req_data_t),
      .hpdcache_req_be_t    (hpdcache_req_be_t),
      .hpdcache_req_sid_t   (hpdcache_req_sid_t),
      .hpdcache_req_tid_t   (hpdcache_req_tid_t),
      .hpdcache_req_t       (hpdcache_req_t),
      .hpdcache_rsp_t       (hpdcache_rsp_t),
      .hpdcache_mem_addr_t  (hpdcache_mem_addr_t),
      .hpdcache_mem_id_t    (hpdcache_mem_id_t),
      .hpdcache_mem_data_t  (hpdcache_mem_data_t),
      .hpdcache_mem_be_t    (hpdcache_mem_bit_en_t),
      .hpdcache_mem_req_t   (hpdcache_mem_req_t),
      .hpdcache_mem_req_w_t (hpdcache_mem_req_bit_w_t),
      .hpdcache_mem_resp_r_t(hpdcache_mem_resp_r_t),
      .hpdcache_mem_resp_w_t(hpdcache_mem_resp_w_t)
  ) i_hpdcache (
      .clk_i,
      .rst_ni,

      .core_req_valid_i(cache_req_valid),
      .core_req_ready_o(cache_req_ready),
      .core_req_i      (cache_req),
      .core_req_abort_i(cache_req_abort),
      .core_req_tag_i  (cache_req_tag),
      .core_req_pma_i  (cache_req_pma),

      .core_rsp_valid_o(cache_rsp_valid),
      .core_rsp_o      (cache_rsp),

      .mem_req_read_ready_i(mem_req_read_ready),
      .mem_req_read_valid_o(mem_req_read_valid),
      .mem_req_read_o(mem_req_read),

      .mem_resp_read_ready_o(mem_resp_read_ready),
      .mem_resp_read_valid_i(mem_resp_read_valid),
      .mem_resp_read_i(mem_resp_read),

      .mem_req_write_ready_i(mem_req_write_ready),
      .mem_req_write_valid_o(mem_req_write_valid),
      .mem_req_write_o(mem_req_write),

      .mem_req_write_data_ready_i(mem_req_write_data_ready),
      .mem_req_write_data_valid_o(mem_req_write_data_valid),
      .mem_req_write_data_o(mem_req_write_data),

      .mem_resp_write_ready_o(mem_resp_write_ready),
      .mem_resp_write_valid_i(mem_resp_write_valid),
      .mem_resp_write_i(mem_resp_write),

      .wbuf_flush_i('0),
      .wbuf_empty_o(),

      .evt_cache_write_miss_o(events_o.cache_write_miss),
      .evt_cache_read_miss_o (events_o.cache_read_miss),
      .evt_uncached_req_o    (events_o.uncached_req),
      .evt_cmo_req_o         (events_o.cmo_req),
      .evt_write_req_o       (events_o.write_req),
      .evt_read_req_o        (events_o.read_req),
      .evt_prefetch_req_o    (events_o.prefetch_req),
      .evt_req_on_hold_o     (events_o.req_on_hold),
      .evt_rtab_rollback_o   (events_o.rtab_rollback),
      .evt_stall_refill_o    (events_o.stall_refill),
      .evt_stall_o           (events_o.stall),

      .cfg_enable_i                       (1'b1), // enable the cache
      .cfg_wbuf_threshold_i               (3'd2),
      .cfg_wbuf_reset_timecnt_on_write_i  (1'b1),
      .cfg_wbuf_sequential_waw_i          (1'b0),
      .cfg_wbuf_inhibit_write_coalescing_i(1'b0),
      .cfg_prefetch_updt_plru_i           (1'b1),
      .cfg_error_on_cacheable_amo_i       (1'b0),
      .cfg_rtab_single_entry_i            (1'b0),
      .cfg_default_wb_i                   (1'b0),
      .mem_resp_read_inval_i              (1'b0),
      .mem_resp_read_inval_nline_i        ('0),
      .cfg_scrub_enable_i                 (1'b0),
      .cfg_scrub_period_i                 ('0),
      .cfg_scrub_restart_i                (1'b0)
  );

endmodule
