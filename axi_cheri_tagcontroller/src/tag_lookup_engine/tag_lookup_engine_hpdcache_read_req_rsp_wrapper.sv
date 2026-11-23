module hpdcache_read_req_rsp_wrapper #(
    parameter hpdcache_pkg::hpdcache_cfg_t HPDcacheCfg = '0,
    parameter type sid_t = logic [HPDcacheCfg.u.reqSrcIdWidth-1:0],
    parameter type tag_req_t = logic,
    parameter type tag_read_resp_t = logic,
    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_tag_t = logic [HPDcacheCfg.tagWidth-1:0],
    parameter type hpdcache_pma_t = hpdcache_pkg::hpdcache_pma_t
  ) (
    input logic clk_i,
    input logic rst_ni,

    input sid_t sid_i,

    input logic read_req_speculative_i,
    input logic read_req_valid_i,
    output logic read_req_ready_o,
    input tag_req_t read_req_i,

    output logic hpdcache_read_req_valid_o,
    input logic hpdcache_read_req_ready_i,
    output hpdcache_req_t hpdcache_read_req_o,
    output logic hpdcache_read_req_abort_o,
    output hpdcache_tag_t hpdcache_read_req_tag_o,
    output hpdcache_pma_t hpdcache_read_req_pma_o,

    output logic read_resp_valid_o,
    output tag_read_resp_t read_resp_o,

    input logic hpdcache_read_resp_valid_i,
    input hpdcache_rsp_t hpdcache_read_resp_i
  );

  // remember the tag of the last accepted address for VIPT mode
  hpdcache_tag_t last_req_addr_tag_q;
  // pulse abort in the cycle after a speculative request is accepted,
  // which is the timing currently required by HPDCache.
  logic abort_pending_q;
  // remember how to shift read responses based on the address
  logic [$clog2($bits(read_resp_o.data))-1:0] shifts [(2**$bits(read_req_i.a_x_id))-1:0];
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      abort_pending_q <= 1'b0;
    end else begin
      if (read_req_valid_i && hpdcache_read_req_ready_i) begin
        shifts[read_req_i.a_x_id] <= read_req_i.a_x_addr;
        last_req_addr_tag_q <= read_req_i.a_x_addr >> HPDcacheCfg.reqOffsetWidth;
        abort_pending_q <= read_req_speculative_i;
      end else begin
        abort_pending_q <= 1'b0;
      end
    end
  end

  always_comb begin

    automatic hpdcache_req_t req;
    // make sure we have a single flit transaction
    assert(read_req_i.a_x_len == 0);
    //assert(read_req_i.x_last == 1'b1);

    // prepare hpdcache req
    req.addr_offset = read_req_i.a_x_addr[0 +: HPDcacheCfg.reqOffsetWidth];
    req.wdata = 0; // read req, no data
    req.op = hpdcache_pkg::HPDCACHE_REQ_LOAD;
    req.be = 0; // read req, no byte enable
    req.size = 0;
    req.sid = sid_i;
    req.tid = read_req_i.a_x_id;
    req.need_rsp = 1'b1;
    req.phys_indexed = 1'b0;
    req.addr_tag = read_req_i.a_x_addr[HPDcacheCfg.reqOffsetWidth +: HPDcacheCfg.tagWidth];
    req.pma.uncacheable = 1'b0;
    req.pma.io = 1'b0;
    req.pma.wr_policy_hint = hpdcache_pkg::HPDCACHE_WR_POLICY_WB;

    // assign outputs
    hpdcache_read_req_o = req;
    hpdcache_read_req_abort_o = abort_pending_q;
    hpdcache_read_req_tag_o = last_req_addr_tag_q;
    hpdcache_read_req_pma_o.uncacheable = 1'b0;
    hpdcache_read_req_pma_o.io = 1'b0;
    hpdcache_read_req_pma_o.wr_policy_hint = hpdcache_pkg::HPDCACHE_WR_POLICY_WB;
  end

  // convert hpdcache read response to tag controller read response
  function automatic tag_read_resp_t hpdcache_read_rsp_to_tagctrl_read_rsp( hpdcache_rsp_t rsp
                                                                          , logic [$clog2($bits(read_resp_o.data))-1:0] shamnt );
    tag_read_resp_t resp;
    resp.id = rsp.tid;
    shamnt[1:0] = 2'b00;
    resp.data = rsp.rdata << shamnt;
    resp.resp = rsp.error ? axi_pkg::RESP_SLVERR : axi_pkg::RESP_OKAY;
    resp.last = 1'b1;
    resp.aborted = rsp.aborted;
    resp.hit = rsp.hit;
    return resp;
  endfunction

  // connect up input / output signals
  assign read_req_ready_o = hpdcache_read_req_ready_i;

  assign hpdcache_read_req_valid_o = read_req_valid_i;

  assign read_resp_valid_o = hpdcache_read_resp_valid_i;
  assign read_resp_o = hpdcache_read_rsp_to_tagctrl_read_rsp( hpdcache_read_resp_i
                                                            , shifts[hpdcache_read_resp_i.tid] );

endmodule
