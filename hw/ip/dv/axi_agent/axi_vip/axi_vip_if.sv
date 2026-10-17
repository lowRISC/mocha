// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Bridge a pulp_axi req/resp struct pair to axi_if and publish the bus through UVM config_db.
// IfMode selects direction: Manager drives axi_req and observes axi_resp; Subordinate observes
// axi_req and drives axi_resp; Monitor observes both.
//
// req_t and resp_t are declared as type parameters, but the body reads their fields by name
// (.aw.id, .w.strb, .r.data and so on), so only the vendored pulp_axi struct shape works.
//
// They exist so that one interface can tap either kind of crossbar port. The crossbar widens the
// AXI ID on its way through, appending the host index so responses can be routed back. So, a
// device port's ID is wider than a host port's. top_pkg therefore declares the same struct twice:
//
//   host ports:   top_pkg::axi_req_t     / top_pkg::axi_resp_t
//   device ports: top_pkg::axi_dev_req_t / top_pkg::axi_dev_resp_t
//
// req_t and resp_t simply say which of those two pairs this instance is connected to.
//
// Configure the bus from width parameters; $bits casts fit maximum-width channel signals to the
// structs. IsLite selects AXI4-Lite for ports behind an AXI4-Lite adapter (see axi_if::set_lite).
//
// The field names this relies on:
//
//   req_t  (everything the manager drives)   resp_t (everything the subordinate drives)
//     .aw / .aw_valid  AW payload + valid      .b  / .b_valid   B payload + valid
//     .w  / .w_valid   W  payload + valid      .r  / .r_valid   R payload + valid
//     .ar / .ar_valid  AR payload + valid      .aw_ready        ready for AW
//     .b_ready         ready for B             .w_ready         ready for W
//     .r_ready         ready for R             .ar_ready        ready for AR
//
// Each payload holds that channel's AXI signals with the channel prefix dropped, so
// .aw.addr is AWADDR, .w.strb is WSTRB, .r.data is RDATA, and so on.

interface axi_vip_if
  import uvm_pkg::*;
  import axi_agent_pkg::*;
#(
  parameter type          req_t     = logic,
  parameter type          resp_t    = logic,
  parameter int           IdWidth   = 32,
  parameter int           AddrWidth = 64,
  parameter int           DataWidth = 64,
  parameter int           UserWidth = 1,
  parameter bit           IsLite    = 1'b0,
  parameter axi_if_mode_e IfMode    = Monitor,
  parameter string        CfgScope  = "*"     // config_db publish scope glob
) (
  input logic clk_i,
  input logic rst_ni
);
  `include "uvm_macros.svh"

  // Drive axi_req in Manager mode and axi_resp in Subordinate mode; observe each otherwise
  req_t  axi_req;
  resp_t axi_resp;

  axi_if u_axi_if (.clk_i(clk_i), .rst_ni(rst_ni));

  // ---------------------------------------------------------------------------
  // Manager packs the request from the bus; other modes unpack the observed request
  // ---------------------------------------------------------------------------
  if (IfMode == Manager) begin : gen_req_drive
    // AW
    assign axi_req.aw.id     = $bits(axi_req.aw.id)'(u_axi_if.aw_if.awid);
    assign axi_req.aw.addr   = $bits(axi_req.aw.addr)'(u_axi_if.aw_if.awaddr);
    assign axi_req.aw.len    = $bits(axi_req.aw.len)'(u_axi_if.aw_if.awlen);
    assign axi_req.aw.size   = $bits(axi_req.aw.size)'(u_axi_if.aw_if.awsize);
    assign axi_req.aw.burst  = $bits(axi_req.aw.burst)'(u_axi_if.aw_if.awburst);
    assign axi_req.aw.lock   = u_axi_if.aw_if.awlock;
    assign axi_req.aw.cache  = $bits(axi_req.aw.cache)'(u_axi_if.aw_if.awcache);
    assign axi_req.aw.prot   = $bits(axi_req.aw.prot)'(u_axi_if.aw_if.awprot);
    assign axi_req.aw.qos    = $bits(axi_req.aw.qos)'(u_axi_if.aw_if.awqos);
    assign axi_req.aw.region = $bits(axi_req.aw.region)'(u_axi_if.aw_if.awregion);
    assign axi_req.aw.atop   = '0;
    assign axi_req.aw.user   = $bits(axi_req.aw.user)'(u_axi_if.aw_if.awuser);
    assign axi_req.aw_valid  = u_axi_if.aw_if.awvalid;
    // W
    assign axi_req.w.data    = $bits(axi_req.w.data)'(u_axi_if.w_if.wdata);
    assign axi_req.w.strb    = $bits(axi_req.w.strb)'(u_axi_if.w_if.wstrb);
    assign axi_req.w.last    = u_axi_if.w_if.wlast;
    assign axi_req.w.user    = $bits(axi_req.w.user)'(u_axi_if.w_if.wuser);
    assign axi_req.w_valid   = u_axi_if.w_if.wvalid;
    // B
    assign axi_req.b_ready   = u_axi_if.b_if.bready;
    // AR
    assign axi_req.ar.id     = $bits(axi_req.ar.id)'(u_axi_if.ar_if.arid);
    assign axi_req.ar.addr   = $bits(axi_req.ar.addr)'(u_axi_if.ar_if.araddr);
    assign axi_req.ar.len    = $bits(axi_req.ar.len)'(u_axi_if.ar_if.arlen);
    assign axi_req.ar.size   = $bits(axi_req.ar.size)'(u_axi_if.ar_if.arsize);
    assign axi_req.ar.burst  = $bits(axi_req.ar.burst)'(u_axi_if.ar_if.arburst);
    assign axi_req.ar.lock   = u_axi_if.ar_if.arlock;
    assign axi_req.ar.cache  = $bits(axi_req.ar.cache)'(u_axi_if.ar_if.arcache);
    assign axi_req.ar.prot   = $bits(axi_req.ar.prot)'(u_axi_if.ar_if.arprot);
    assign axi_req.ar.qos    = $bits(axi_req.ar.qos)'(u_axi_if.ar_if.arqos);
    assign axi_req.ar.region = $bits(axi_req.ar.region)'(u_axi_if.ar_if.arregion);
    assign axi_req.ar.user   = $bits(axi_req.ar.user)'(u_axi_if.ar_if.aruser);
    assign axi_req.ar_valid  = u_axi_if.ar_if.arvalid;
    // R
    assign axi_req.r_ready   = u_axi_if.r_if.rready;
  end else begin : gen_req_observe
    // AW
    assign u_axi_if.aw_if.awid     = $bits(u_axi_if.aw_if.awid)'(axi_req.aw.id);
    assign u_axi_if.aw_if.awaddr   = $bits(u_axi_if.aw_if.awaddr)'(axi_req.aw.addr);
    assign u_axi_if.aw_if.awlen    = $bits(u_axi_if.aw_if.awlen)'(axi_req.aw.len);
    assign u_axi_if.aw_if.awsize   = $bits(u_axi_if.aw_if.awsize)'(axi_req.aw.size);
    assign u_axi_if.aw_if.awburst  = $bits(u_axi_if.aw_if.awburst)'(axi_req.aw.burst);
    assign u_axi_if.aw_if.awlock   = axi_req.aw.lock;
    assign u_axi_if.aw_if.awcache  = $bits(u_axi_if.aw_if.awcache)'(axi_req.aw.cache);
    assign u_axi_if.aw_if.awprot   = $bits(u_axi_if.aw_if.awprot)'(axi_req.aw.prot);
    assign u_axi_if.aw_if.awqos    = $bits(u_axi_if.aw_if.awqos)'(axi_req.aw.qos);
    assign u_axi_if.aw_if.awregion = $bits(u_axi_if.aw_if.awregion)'(axi_req.aw.region);
    assign u_axi_if.aw_if.awuser   = $bits(u_axi_if.aw_if.awuser)'(axi_req.aw.user);
    assign u_axi_if.aw_if.awvalid  = axi_req.aw_valid;
    // W
    assign u_axi_if.w_if.wdata     = $bits(u_axi_if.w_if.wdata)'(axi_req.w.data);
    assign u_axi_if.w_if.wstrb     = $bits(u_axi_if.w_if.wstrb)'(axi_req.w.strb);
    assign u_axi_if.w_if.wlast     = axi_req.w.last;
    assign u_axi_if.w_if.wuser     = $bits(u_axi_if.w_if.wuser)'(axi_req.w.user);
    assign u_axi_if.w_if.wvalid    = axi_req.w_valid;
    // B
    assign u_axi_if.b_if.bready    = axi_req.b_ready;
    // AR
    assign u_axi_if.ar_if.arid     = $bits(u_axi_if.ar_if.arid)'(axi_req.ar.id);
    assign u_axi_if.ar_if.araddr   = $bits(u_axi_if.ar_if.araddr)'(axi_req.ar.addr);
    assign u_axi_if.ar_if.arlen    = $bits(u_axi_if.ar_if.arlen)'(axi_req.ar.len);
    assign u_axi_if.ar_if.arsize   = $bits(u_axi_if.ar_if.arsize)'(axi_req.ar.size);
    assign u_axi_if.ar_if.arburst  = $bits(u_axi_if.ar_if.arburst)'(axi_req.ar.burst);
    assign u_axi_if.ar_if.arlock   = axi_req.ar.lock;
    assign u_axi_if.ar_if.arcache  = $bits(u_axi_if.ar_if.arcache)'(axi_req.ar.cache);
    assign u_axi_if.ar_if.arprot   = $bits(u_axi_if.ar_if.arprot)'(axi_req.ar.prot);
    assign u_axi_if.ar_if.arqos    = $bits(u_axi_if.ar_if.arqos)'(axi_req.ar.qos);
    assign u_axi_if.ar_if.arregion = $bits(u_axi_if.ar_if.arregion)'(axi_req.ar.region);
    assign u_axi_if.ar_if.aruser   = $bits(u_axi_if.ar_if.aruser)'(axi_req.ar.user);
    assign u_axi_if.ar_if.arvalid  = axi_req.ar_valid;
    // R
    assign u_axi_if.r_if.rready    = axi_req.r_ready;
  end

  // ---------------------------------------------------------------------------
  // Subordinate packs the response from the bus; other modes unpack the observed response
  // ---------------------------------------------------------------------------
  if (IfMode == Subordinate) begin : gen_resp_drive
    assign axi_resp.aw_ready = u_axi_if.aw_if.awready;
    assign axi_resp.w_ready  = u_axi_if.w_if.wready;
    assign axi_resp.b_valid  = u_axi_if.b_if.bvalid;
    assign axi_resp.b.id     = $bits(axi_resp.b.id)'(u_axi_if.b_if.bid);
    assign axi_resp.b.resp   = $bits(axi_resp.b.resp)'(u_axi_if.b_if.bresp);
    assign axi_resp.b.user   = $bits(axi_resp.b.user)'(u_axi_if.b_if.buser);
    assign axi_resp.ar_ready = u_axi_if.ar_if.arready;
    assign axi_resp.r_valid  = u_axi_if.r_if.rvalid;
    assign axi_resp.r.id     = $bits(axi_resp.r.id)'(u_axi_if.r_if.rid);
    assign axi_resp.r.data   = $bits(axi_resp.r.data)'(u_axi_if.r_if.rdata);
    assign axi_resp.r.resp   = $bits(axi_resp.r.resp)'(u_axi_if.r_if.rresp);
    assign axi_resp.r.last   = u_axi_if.r_if.rlast;
    assign axi_resp.r.user   = $bits(axi_resp.r.user)'(u_axi_if.r_if.ruser);
  end else begin : gen_resp_observe
    assign u_axi_if.aw_if.awready = axi_resp.aw_ready;
    assign u_axi_if.w_if.wready   = axi_resp.w_ready;
    assign u_axi_if.b_if.bvalid   = axi_resp.b_valid;
    assign u_axi_if.b_if.bid      = $bits(u_axi_if.b_if.bid)'(axi_resp.b.id);
    assign u_axi_if.b_if.bresp    = $bits(u_axi_if.b_if.bresp)'(axi_resp.b.resp);
    assign u_axi_if.b_if.buser    = $bits(u_axi_if.b_if.buser)'(axi_resp.b.user);
    assign u_axi_if.ar_if.arready = axi_resp.ar_ready;
    assign u_axi_if.r_if.rvalid   = axi_resp.r_valid;
    assign u_axi_if.r_if.rid      = $bits(u_axi_if.r_if.rid)'(axi_resp.r.id);
    assign u_axi_if.r_if.rdata    = $bits(u_axi_if.r_if.rdata)'(axi_resp.r.data);
    assign u_axi_if.r_if.rresp    = $bits(u_axi_if.r_if.rresp)'(axi_resp.r.resp);
    assign u_axi_if.r_if.rlast    = axi_resp.r.last;
    assign u_axi_if.r_if.ruser    = $bits(u_axi_if.r_if.ruser)'(axi_resp.r.user);
  end

  // Reject atomic AW handshakes: axi_if has no AWATOP, so a Subordinate agent would treat them as
  // plain writes (AMBA AXI H.c E1.1)
  if (IfMode == Subordinate) begin : gen_atop_check
    always @(posedge clk_i) begin
      if (rst_ni === 1'b1 && axi_req.aw_valid === 1'b1 && axi_resp.aw_ready === 1'b1 &&
          axi_req.aw.atop !== '0) begin
        `uvm_error("axi_vip_if",
                   $sformatf({"AW request with AWATOP 0x%0h at address 0x%0h: atomic ",
                              "transactions are not supported yet."},
                             axi_req.aw.atop, axi_req.aw.addr))
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Configure the bus and publish it and the agent's activity
  // ---------------------------------------------------------------------------
  initial begin
    u_axi_if.set_if_mode(IfMode);
    u_axi_if.set_user_width(UserWidth);
    // The struct carries RUSER as a single user field, so the response half of RUSER is empty
    u_axi_if.r_if.set_user_resp_width(0);
    u_axi_if.set_id_width(IdWidth);
    u_axi_if.set_addr_width(AddrWidth);
    u_axi_if.set_data_width(DataWidth);
    u_axi_if.set_resp_width($bits(axi_resp.b.resp));
    u_axi_if.set_lite(IsLite);

    uvm_config_db#(axi_vif_t)::set(null, CfgScope, "vif", u_axi_if);
    uvm_config_db#(uvm_active_passive_enum)::set(null, CfgScope, "is_active",
                                                 (IfMode == Monitor) ? UVM_PASSIVE : UVM_ACTIVE);
  end

  // Direction labels (documentary; the DUT connection uses struct assigns).
  modport manager (output axi_req, input axi_resp);
  modport monitor (input  axi_req, input axi_resp);
endinterface
