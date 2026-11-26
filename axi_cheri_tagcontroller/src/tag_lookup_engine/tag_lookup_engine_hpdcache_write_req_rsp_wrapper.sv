module hpdcache_write_req_rsp_wrapper #(
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type sid_t = logic [HPDcacheCfg.u.reqSrcIdWidth-1:0],
    parameter type tag_req_t = logic,
    parameter type tag_data_req_t = logic,
    parameter type tag_write_resp_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic
  ) (
    input logic clk_i,
    input logic rst_ni,

    input sid_t sid_i,

    input logic write_req_valid_i,
    output logic write_req_ready_o,
    input tag_req_t write_req_i,
    input logic write_req_flush_i,

    input logic write_data_req_valid_i,
    output logic write_data_req_ready_o,
    input tag_data_req_t write_data_req_i,

    output logic hpdcache_write_req_valid_o,
    input logic hpdcache_write_req_ready_i,
    output hpdcache_req_t hpdcache_write_req_o,

    output logic write_resp_valid_o,
    output tag_write_resp_t write_resp_o,

    input logic hpdcache_write_resp_valid_i,
    input hpdcache_rsp_t hpdcache_write_resp_i
  );

  // convert write descriptor to hpdcache request
  function automatic hpdcache_req_t write_req_to_hpdcache_req(tag_req_t desc, tag_data_req_t wdata, logic flush);

    hpdcache_req_t req;

    localparam int hi = $clog2($bits(wdata.data)) - 1;
    localparam int lo = $clog2(HPDcacheCfg.reqDataBytes);
    logic [hi:0] sel = {write_req_i.a_x_addr[hi:lo], {lo{1'b0}}};

    // make sure we have a single flit transaction
    assert(desc.a_x_len == 0);
    //assert(desc.x_last == 1'b1); // TODO only check if there is a valid request
    // TODO check remaining descriptor fields
    //axi_pkg::burst_t a_x_burst;  // AXI burst type
    //logic a_x_lock;  // AXI lock signal
    //axi_pkg::cache_t a_x_cache;  // AXI cache signal
    //axi_pkg::prot_t a_x_prot;  // AXI protection signal
    //axi_pkg::resp_t x_resp;  // AXI response signal, for error propagation
    //logic x_last;  // Last descriptor of a burst
    //// Cache specific descriptor signals
    //logic [Cfg.tagc_cfg.SetAssociativity-1:0] way_ind;  // way we have to perform an operation on

    // prepare hpdcache req
    req.addr_offset = desc.a_x_addr[0 +: HPDcacheCfg.reqOffsetWidth];
    req.wdata = wdata.data >> sel;
    req.op = flush ? hpdcache_pkg::HPDCACHE_REQ_CMO_FLUSH_INVAL_ALL : hpdcache_pkg::HPDCACHE_REQ_STORE;
    req.be = wdata.bit_en >> sel;
    req.size = 0;
    req.sid = sid_i;
    req.tid = desc.a_x_id;
    req.need_rsp = 1'b1;
    req.phys_indexed = 1'b1;
    req.addr_tag = desc.a_x_addr[HPDcacheCfg.reqOffsetWidth +: HPDcacheCfg.tagWidth];
    req.pma.uncacheable = 1'b0;
    req.pma.io = 1'b0;
    req.pma.wr_policy_hint = hpdcache_pkg::HPDCACHE_WR_POLICY_WB;
    //req.pma.wr_policy_hint = hpdcache_pkg::HPDCACHE_WR_POLICY_WT;
    return req;
  endfunction

  function automatic tag_write_resp_t hpdcache_write_rsp_to_tagctrl_write_rsp(hpdcache_rsp_t rsp);
    tag_write_resp_t resp;
    resp.id = rsp.tid;
    resp.resp = (rsp.error || rsp.aborted) ? axi_pkg::RESP_SLVERR : axi_pkg::RESP_OKAY;
    resp.user = 1'b0; // unused
    return resp;
  endfunction

  logic write_req_valid;
  assign write_req_valid = write_req_valid_i & write_data_req_valid_i;
  assign write_req_ready_o = write_req_valid && hpdcache_write_req_ready_i;
  assign write_data_req_ready_o = write_req_valid && hpdcache_write_req_ready_i;
  assign hpdcache_write_req_valid_o = write_req_valid;
  assign hpdcache_write_req_o = write_req_to_hpdcache_req(write_req_i, write_data_req_i, write_req_flush_i);
  assign write_resp_valid_o = hpdcache_write_resp_valid_i;
  assign write_resp_o = hpdcache_write_rsp_to_tagctrl_write_rsp(hpdcache_write_resp_i);

endmodule
