// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Reusable AXI VIP connection interface: instantiates the five axi_agent channel
// interfaces, bridges them to a packed AXI req/resp struct pair, and publishes them
// to the UVM config_db as one axi_agent_cfg. Parameterized on the req/resp struct
// types + widths, and on IsActive:
//   UVM_ACTIVE  -> manager: drives axi_req from the driven channels (Host mode).
//   UVM_PASSIVE -> monitor: observes axi_req + axi_resp (Monitor mode).

interface axi_vip_if #(
  parameter type req_t     = logic,
  parameter type resp_t    = logic,
  parameter int  IdWidth   = 32,
  parameter int  AddrWidth = 64,
  parameter int  DataWidth = 64,
  parameter int  UserWidth = 1,
  parameter uvm_pkg::uvm_active_passive_enum IsActive = uvm_pkg::UVM_ACTIVE,
  parameter string InstId   = "axi_mgr",   // cfg.inst_id (log tag)
  parameter string CfgScope = "*"          // config_db publish scope glob
) (
  input logic clk_i,
  input logic rst_ni
);

  import uvm_pkg::*;
  import axi_agent_pkg::*;
  `include "uvm_macros.svh"

  // DUT-facing struct pair. axi_req is driven by this interface when ACTIVE and
  // observed when PASSIVE; axi_resp is always observed.
  req_t  axi_req;
  resp_t axi_resp;

  clk_rst_if            u_clk_rst_if  (.clk  (clk_i), .rst_n (rst_ni));
  axi_write_request_if  aw_if         (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_data_if     w_if          (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_response_if b_if          (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_request_if   ar_if         (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_data_if      r_if          (.clk_i(clk_i), .rst_ni(rst_ni));

  // ---------------------------------------------------------------------------
  // Request bridge (manager-driven channels): ACTIVE packs axi_req from the
  // driven interfaces; PASSIVE unpacks the observed axi_req onto the interfaces.
  // ---------------------------------------------------------------------------
  if (IsActive == UVM_ACTIVE) begin : gen_req_drive
    // AW
    assign axi_req.aw.id     = $bits(axi_req.aw.id)'(aw_if.awid);
    assign axi_req.aw.addr   = $bits(axi_req.aw.addr)'(aw_if.awaddr);
    assign axi_req.aw.len    = $bits(axi_req.aw.len)'(aw_if.awlen);
    assign axi_req.aw.size   = $bits(axi_req.aw.size)'(aw_if.awsize);
    assign axi_req.aw.burst  = $bits(axi_req.aw.burst)'(aw_if.awburst);
    assign axi_req.aw.lock   = aw_if.awlock;
    assign axi_req.aw.cache  = $bits(axi_req.aw.cache)'(aw_if.awcache);
    assign axi_req.aw.prot   = $bits(axi_req.aw.prot)'(aw_if.awprot);
    assign axi_req.aw.qos    = $bits(axi_req.aw.qos)'(aw_if.awqos);
    assign axi_req.aw.region = $bits(axi_req.aw.region)'(aw_if.awregion);
    assign axi_req.aw.atop   = '0;
    assign axi_req.aw.user   = $bits(axi_req.aw.user)'(aw_if.awuser);
    assign axi_req.aw_valid  = aw_if.awvalid;
    // W: WDATA/WSTRB/WUSER are don't-cares (undriven X) when WVALID is low; drive
    // defined zeros so the SRAM adapter never forwards X into its request FIFO.
    assign axi_req.w.data    = w_if.wvalid ? $bits(axi_req.w.data)'(w_if.wdata) : '0;
    assign axi_req.w.strb    = w_if.wvalid ? $bits(axi_req.w.strb)'(w_if.wstrb) : '0;
    assign axi_req.w.last    = w_if.wlast;
    assign axi_req.w.user    = w_if.wvalid ? $bits(axi_req.w.user)'(w_if.wuser) : '0;
    assign axi_req.w_valid   = w_if.wvalid;
    // B
    assign axi_req.b_ready   = b_if.bready;
    // AR
    assign axi_req.ar.id     = $bits(axi_req.ar.id)'(ar_if.arid);
    assign axi_req.ar.addr   = $bits(axi_req.ar.addr)'(ar_if.araddr);
    assign axi_req.ar.len    = $bits(axi_req.ar.len)'(ar_if.arlen);
    assign axi_req.ar.size   = $bits(axi_req.ar.size)'(ar_if.arsize);
    assign axi_req.ar.burst  = $bits(axi_req.ar.burst)'(ar_if.arburst);
    assign axi_req.ar.lock   = ar_if.arlock;
    assign axi_req.ar.cache  = $bits(axi_req.ar.cache)'(ar_if.arcache);
    assign axi_req.ar.prot   = $bits(axi_req.ar.prot)'(ar_if.arprot);
    assign axi_req.ar.qos    = $bits(axi_req.ar.qos)'(ar_if.arqos);
    assign axi_req.ar.region = $bits(axi_req.ar.region)'(ar_if.arregion);
    assign axi_req.ar.user   = $bits(axi_req.ar.user)'(ar_if.aruser);
    assign axi_req.ar_valid  = ar_if.arvalid;
    // R
    assign axi_req.r_ready   = r_if.rready;
  end else begin : gen_req_observe
    // AW
    assign aw_if.awid     = $bits(aw_if.awid)'(axi_req.aw.id);
    assign aw_if.awaddr   = $bits(aw_if.awaddr)'(axi_req.aw.addr);
    assign aw_if.awlen    = $bits(aw_if.awlen)'(axi_req.aw.len);
    assign aw_if.awsize   = $bits(aw_if.awsize)'(axi_req.aw.size);
    assign aw_if.awburst  = $bits(aw_if.awburst)'(axi_req.aw.burst);
    assign aw_if.awlock   = axi_req.aw.lock;
    assign aw_if.awcache  = $bits(aw_if.awcache)'(axi_req.aw.cache);
    assign aw_if.awprot   = $bits(aw_if.awprot)'(axi_req.aw.prot);
    assign aw_if.awqos    = $bits(aw_if.awqos)'(axi_req.aw.qos);
    assign aw_if.awregion = $bits(aw_if.awregion)'(axi_req.aw.region);
    assign aw_if.awuser   = $bits(aw_if.awuser)'(axi_req.aw.user);
    assign aw_if.awvalid  = axi_req.aw_valid;
    // W
    assign w_if.wdata     = $bits(w_if.wdata)'(axi_req.w.data);
    assign w_if.wstrb     = $bits(w_if.wstrb)'(axi_req.w.strb);
    assign w_if.wlast     = axi_req.w.last;
    assign w_if.wuser     = $bits(w_if.wuser)'(axi_req.w.user);
    assign w_if.wvalid    = axi_req.w_valid;
    // B
    assign b_if.bready    = axi_req.b_ready;
    // AR
    assign ar_if.arid     = $bits(ar_if.arid)'(axi_req.ar.id);
    assign ar_if.araddr   = $bits(ar_if.araddr)'(axi_req.ar.addr);
    assign ar_if.arlen    = $bits(ar_if.arlen)'(axi_req.ar.len);
    assign ar_if.arsize   = $bits(ar_if.arsize)'(axi_req.ar.size);
    assign ar_if.arburst  = $bits(ar_if.arburst)'(axi_req.ar.burst);
    assign ar_if.arlock   = axi_req.ar.lock;
    assign ar_if.arcache  = $bits(ar_if.arcache)'(axi_req.ar.cache);
    assign ar_if.arprot   = $bits(ar_if.arprot)'(axi_req.ar.prot);
    assign ar_if.arqos    = $bits(ar_if.arqos)'(axi_req.ar.qos);
    assign ar_if.arregion = $bits(ar_if.arregion)'(axi_req.ar.region);
    assign ar_if.aruser   = $bits(ar_if.aruser)'(axi_req.ar.user);
    assign ar_if.arvalid  = axi_req.ar_valid;
    // R
    assign r_if.rready    = axi_req.r_ready;
  end

  // ---------------------------------------------------------------------------
  // Response bridge (subordinate-driven channels): always observed onto the ifs.
  // ---------------------------------------------------------------------------
  assign aw_if.awready = axi_resp.aw_ready;
  assign w_if.wready   = axi_resp.w_ready;
  assign b_if.bvalid   = axi_resp.b_valid;
  assign b_if.bid      = $bits(b_if.bid)'(axi_resp.b.id);
  assign b_if.bresp    = $bits(b_if.bresp)'(axi_resp.b.resp);
  assign b_if.buser    = $bits(b_if.buser)'(axi_resp.b.user);
  assign ar_if.arready = axi_resp.ar_ready;
  assign r_if.rvalid   = axi_resp.r_valid;
  assign r_if.rid      = $bits(r_if.rid)'(axi_resp.r.id);
  assign r_if.rdata    = $bits(r_if.rdata)'(axi_resp.r.data);
  assign r_if.rresp    = $bits(r_if.rresp)'(axi_resp.r.resp);
  assign r_if.rlast    = axi_resp.r.last;
  assign r_if.ruser    = $bits(r_if.ruser)'(axi_resp.r.user);

  // ---------------------------------------------------------------------------
  // Interface widths + mode; build + publish the cfg (is_active from IsActive).
  // ---------------------------------------------------------------------------
  initial begin
    dv_utils_pkg::if_mode_e mode = (IsActive == UVM_ACTIVE) ? dv_utils_pkg::Host
                                                            : dv_utils_pkg::Monitor;
    axi_agent_cfg agent_cfg = new("agent_cfg");
    agent_cfg.set_config(.inst_id(InstId), .is_active(IsActive));

    aw_if.set_id_w_width(IdWidth);
    aw_if.set_addr_width(AddrWidth);
    aw_if.set_user_req_width(UserWidth);
    aw_if.if_mode = mode;

    w_if.set_user_data_width(UserWidth);
    w_if.set_data_width(DataWidth);
    w_if.if_mode = mode;

    b_if.set_id_w_width(IdWidth);
    b_if.set_bresp_width($bits(axi_resp.b.resp));
    b_if.set_user_resp_width(UserWidth);
    b_if.if_mode = mode;

    ar_if.set_id_r_width(IdWidth);
    ar_if.set_addr_width(AddrWidth);
    ar_if.set_user_req_width(UserWidth);
    ar_if.if_mode = mode;

    r_if.set_id_r_width(IdWidth);
    r_if.set_user_data_width(UserWidth);
    r_if.set_data_width(DataWidth);
    r_if.set_rresp_width($bits(axi_resp.r.resp));
    r_if.set_user_resp_width(UserWidth);
    r_if.if_mode = mode;

    agent_cfg.write_request_vif  = aw_if;
    agent_cfg.write_data_vif     = w_if;
    agent_cfg.write_response_vif = b_if;
    agent_cfg.read_request_vif   = ar_if;
    agent_cfg.read_data_vif      = r_if;
    agent_cfg.clk_rst_vif        = u_clk_rst_if;
    uvm_config_db#(axi_agent_cfg)::set(null, CfgScope, "cfg", agent_cfg);
  end

  // Direction labels (documentary; the DUT connection uses struct assigns).
  modport manager (output axi_req, input axi_resp);
  modport monitor (input  axi_req, input axi_resp);
endinterface
