// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This AXI4 VIP shall be always UVM_PASSIVE on top level
  // LHS is the VIP, RHS is the RTL
  // =========================================================
  // mst0 - Tapping the XBAR Slave Port 0 (Master VIP side)
  // =========================================================
  assign axi4_mgr_if[top_pkg::CVA6].aclk    = clk;
  assign axi4_mgr_if[top_pkg::CVA6].aresetn = rst_n;
  
  always_comb begin
    // Request signals (Master -> XBAR)
    axi4_mgr_if[top_pkg::CVA6].awvalid  = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw_valid;
    axi4_mgr_if[top_pkg::CVA6].awid     = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.id;
    axi4_mgr_if[top_pkg::CVA6].awaddr   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.addr;
    axi4_mgr_if[top_pkg::CVA6].awlen    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.len;
    axi4_mgr_if[top_pkg::CVA6].awsize   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.size;
    axi4_mgr_if[top_pkg::CVA6].awburst  = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.burst;
    axi4_mgr_if[top_pkg::CVA6].awlock   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.lock;
    axi4_mgr_if[top_pkg::CVA6].awcache  = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.cache;
    axi4_mgr_if[top_pkg::CVA6].awprot   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.prot;
    axi4_mgr_if[top_pkg::CVA6].awqos    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.qos;
    axi4_mgr_if[top_pkg::CVA6].awregion = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.region;
    axi4_mgr_if[top_pkg::CVA6].awuser   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].aw.user;

    axi4_mgr_if[top_pkg::CVA6].wvalid   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].w_valid;
    axi4_mgr_if[top_pkg::CVA6].wdata    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].w.data;
    axi4_mgr_if[top_pkg::CVA6].wstrb    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].w.strb;
    axi4_mgr_if[top_pkg::CVA6].wlast    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].w.last;
    axi4_mgr_if[top_pkg::CVA6].wuser    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].w.user;

    axi4_mgr_if[top_pkg::CVA6].arvalid  = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar_valid;
    axi4_mgr_if[top_pkg::CVA6].arid     = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.id;
    axi4_mgr_if[top_pkg::CVA6].araddr   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.addr;
    axi4_mgr_if[top_pkg::CVA6].arlen    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.len;
    axi4_mgr_if[top_pkg::CVA6].arsize   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.size;
    axi4_mgr_if[top_pkg::CVA6].arburst  = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.burst;
    axi4_mgr_if[top_pkg::CVA6].arlock   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.lock;
    axi4_mgr_if[top_pkg::CVA6].arcache  = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.cache;
    axi4_mgr_if[top_pkg::CVA6].arprot   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.prot;
    axi4_mgr_if[top_pkg::CVA6].arqos    = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.qos;
    axi4_mgr_if[top_pkg::CVA6].arregion = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.region;
    axi4_mgr_if[top_pkg::CVA6].aruser   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].ar.user;

    axi4_mgr_if[top_pkg::CVA6].bready   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].b_ready;
    axi4_mgr_if[top_pkg::CVA6].rready   = `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6].r_ready;

    // Response signals (XBAR -> Master)
    axi4_mgr_if[top_pkg::CVA6].awready  = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].aw_ready;
    axi4_mgr_if[top_pkg::CVA6].wready   = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].w_ready;
    axi4_mgr_if[top_pkg::CVA6].arready  = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].ar_ready;
    
    axi4_mgr_if[top_pkg::CVA6].bvalid   = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].b_valid;
    axi4_mgr_if[top_pkg::CVA6].bid      = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].b.id;
    axi4_mgr_if[top_pkg::CVA6].bresp    = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].b.resp;
    axi4_mgr_if[top_pkg::CVA6].buser    = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].b.user;

    axi4_mgr_if[top_pkg::CVA6].rvalid   = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].r_valid;
    axi4_mgr_if[top_pkg::CVA6].rid      = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].r.id;
    axi4_mgr_if[top_pkg::CVA6].rdata    = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].r.data;
    axi4_mgr_if[top_pkg::CVA6].rresp    = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].r.resp;
    axi4_mgr_if[top_pkg::CVA6].rlast    = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].r.last;
    axi4_mgr_if[top_pkg::CVA6].ruser    = `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6].r.user;
  end

  // =========================================================
  // slv0 - Tapping the XBAR Master Port 0 (Slave VIP side)
  // =========================================================
  assign axi4_sub_if[top_pkg::SRAM].aclk    = clk;
  assign axi4_sub_if[top_pkg::SRAM].aresetn = rst_n;

  always_comb begin
    // Request signals (XBAR -> Slave)
    axi4_sub_if[top_pkg::SRAM].awvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw_valid;
    axi4_sub_if[top_pkg::SRAM].awid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.id;
    axi4_sub_if[top_pkg::SRAM].awaddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.addr;
    axi4_sub_if[top_pkg::SRAM].awlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.len;
    axi4_sub_if[top_pkg::SRAM].awsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.size;
    axi4_sub_if[top_pkg::SRAM].awburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.burst;
    axi4_sub_if[top_pkg::SRAM].awlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.lock;
    axi4_sub_if[top_pkg::SRAM].awcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.cache;
    axi4_sub_if[top_pkg::SRAM].awprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.prot;
    axi4_sub_if[top_pkg::SRAM].awqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.qos;
    axi4_sub_if[top_pkg::SRAM].awregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.region;
    axi4_sub_if[top_pkg::SRAM].awuser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].aw.user;

    axi4_sub_if[top_pkg::SRAM].wvalid   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].w_valid;
    axi4_sub_if[top_pkg::SRAM].wdata    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].w.data;
    axi4_sub_if[top_pkg::SRAM].wstrb    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].w.strb;
    axi4_sub_if[top_pkg::SRAM].wlast    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].w.last;
    axi4_sub_if[top_pkg::SRAM].wuser    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].w.user;

    axi4_sub_if[top_pkg::SRAM].arvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar_valid;
    axi4_sub_if[top_pkg::SRAM].arid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.id;
    axi4_sub_if[top_pkg::SRAM].araddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.addr;
    axi4_sub_if[top_pkg::SRAM].arlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.len;
    axi4_sub_if[top_pkg::SRAM].arsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.size;
    axi4_sub_if[top_pkg::SRAM].arburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.burst;
    axi4_sub_if[top_pkg::SRAM].arlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.lock;
    axi4_sub_if[top_pkg::SRAM].arcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.cache;
    axi4_sub_if[top_pkg::SRAM].arprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.prot;
    axi4_sub_if[top_pkg::SRAM].arqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.qos;
    axi4_sub_if[top_pkg::SRAM].arregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.region;
    axi4_sub_if[top_pkg::SRAM].aruser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].ar.user;

    axi4_sub_if[top_pkg::SRAM].bready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].b_ready;
    axi4_sub_if[top_pkg::SRAM].rready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM].r_ready;

    // Response signals (Slave -> XBAR)
    axi4_sub_if[top_pkg::SRAM].awready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].aw_ready;
    axi4_sub_if[top_pkg::SRAM].wready   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].w_ready;
    axi4_sub_if[top_pkg::SRAM].arready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].ar_ready;
    
    axi4_sub_if[top_pkg::SRAM].bvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].b_valid;
    axi4_sub_if[top_pkg::SRAM].bid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].b.id;
    axi4_sub_if[top_pkg::SRAM].bresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].b.resp;
    axi4_sub_if[top_pkg::SRAM].buser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].b.user;

    axi4_sub_if[top_pkg::SRAM].rvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].r_valid;
    axi4_sub_if[top_pkg::SRAM].rid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].r.id;
    axi4_sub_if[top_pkg::SRAM].rdata    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].r.data;
    axi4_sub_if[top_pkg::SRAM].rresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].r.resp;
    axi4_sub_if[top_pkg::SRAM].rlast    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].r.last;
    axi4_sub_if[top_pkg::SRAM].ruser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM].r.user;
  end

  // =========================================================
  // slv1 - Tapping the XBAR Master Port 1 (Slave VIP side)
  // =========================================================
  assign axi4_sub_if[top_pkg::Mailbox].aclk    = clk;
  assign axi4_sub_if[top_pkg::Mailbox].aresetn = rst_n;

  always_comb begin
    // Request signals (XBAR -> Slave)
    axi4_sub_if[top_pkg::Mailbox].awvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw_valid;
    axi4_sub_if[top_pkg::Mailbox].awid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.id;
    axi4_sub_if[top_pkg::Mailbox].awaddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.addr;
    axi4_sub_if[top_pkg::Mailbox].awlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.len;
    axi4_sub_if[top_pkg::Mailbox].awsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.size;
    axi4_sub_if[top_pkg::Mailbox].awburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.burst;
    axi4_sub_if[top_pkg::Mailbox].awlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.lock;
    axi4_sub_if[top_pkg::Mailbox].awcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.cache;
    axi4_sub_if[top_pkg::Mailbox].awprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.prot;
    axi4_sub_if[top_pkg::Mailbox].awqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.qos;
    axi4_sub_if[top_pkg::Mailbox].awregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.region;
    axi4_sub_if[top_pkg::Mailbox].awuser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].aw.user;

    axi4_sub_if[top_pkg::Mailbox].wvalid   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].w_valid;
    axi4_sub_if[top_pkg::Mailbox].wdata    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].w.data;
    axi4_sub_if[top_pkg::Mailbox].wstrb    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].w.strb;
    axi4_sub_if[top_pkg::Mailbox].wlast    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].w.last;
    axi4_sub_if[top_pkg::Mailbox].wuser    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].w.user;

    axi4_sub_if[top_pkg::Mailbox].arvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar_valid;
    axi4_sub_if[top_pkg::Mailbox].arid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.id;
    axi4_sub_if[top_pkg::Mailbox].araddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.addr;
    axi4_sub_if[top_pkg::Mailbox].arlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.len;
    axi4_sub_if[top_pkg::Mailbox].arsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.size;
    axi4_sub_if[top_pkg::Mailbox].arburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.burst;
    axi4_sub_if[top_pkg::Mailbox].arlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.lock;
    axi4_sub_if[top_pkg::Mailbox].arcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.cache;
    axi4_sub_if[top_pkg::Mailbox].arprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.prot;
    axi4_sub_if[top_pkg::Mailbox].arqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.qos;
    axi4_sub_if[top_pkg::Mailbox].arregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.region;
    axi4_sub_if[top_pkg::Mailbox].aruser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].ar.user;

    axi4_sub_if[top_pkg::Mailbox].bready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].b_ready;
    axi4_sub_if[top_pkg::Mailbox].rready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox].r_ready;

    // Response signals (Slave -> XBAR)
    axi4_sub_if[top_pkg::Mailbox].awready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].aw_ready;
    axi4_sub_if[top_pkg::Mailbox].wready   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].w_ready;
    axi4_sub_if[top_pkg::Mailbox].arready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].ar_ready;
    
    axi4_sub_if[top_pkg::Mailbox].bvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].b_valid;
    axi4_sub_if[top_pkg::Mailbox].bid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].b.id;
    axi4_sub_if[top_pkg::Mailbox].bresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].b.resp;
    axi4_sub_if[top_pkg::Mailbox].buser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].b.user;

    axi4_sub_if[top_pkg::Mailbox].rvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].r_valid;
    axi4_sub_if[top_pkg::Mailbox].rid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].r.id;
    axi4_sub_if[top_pkg::Mailbox].rdata    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].r.data;
    axi4_sub_if[top_pkg::Mailbox].rresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].r.resp;
    axi4_sub_if[top_pkg::Mailbox].rlast    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].r.last;
    axi4_sub_if[top_pkg::Mailbox].ruser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox].r.user;
  end

  // =========================================================
  // slv2 - Tapping the XBAR Master Port 2 (Slave VIP side)
  // =========================================================
  assign axi4_sub_if[top_pkg::TlCrossbar].aclk    = clk;
  assign axi4_sub_if[top_pkg::TlCrossbar].aresetn = rst_n;

  always_comb begin
    // Request signals (XBAR -> Slave)
    axi4_sub_if[top_pkg::TlCrossbar].awvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw_valid;
    axi4_sub_if[top_pkg::TlCrossbar].awid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.id;
    axi4_sub_if[top_pkg::TlCrossbar].awaddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.addr;
    axi4_sub_if[top_pkg::TlCrossbar].awlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.len;
    axi4_sub_if[top_pkg::TlCrossbar].awsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.size;
    axi4_sub_if[top_pkg::TlCrossbar].awburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.burst;
    axi4_sub_if[top_pkg::TlCrossbar].awlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.lock;
    axi4_sub_if[top_pkg::TlCrossbar].awcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.cache;
    axi4_sub_if[top_pkg::TlCrossbar].awprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.prot;
    axi4_sub_if[top_pkg::TlCrossbar].awqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.qos;
    axi4_sub_if[top_pkg::TlCrossbar].awregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.region;
    axi4_sub_if[top_pkg::TlCrossbar].awuser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].aw.user;

    axi4_sub_if[top_pkg::TlCrossbar].wvalid   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].w_valid;
    axi4_sub_if[top_pkg::TlCrossbar].wdata    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].w.data;
    axi4_sub_if[top_pkg::TlCrossbar].wstrb    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].w.strb;
    axi4_sub_if[top_pkg::TlCrossbar].wlast    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].w.last;
    axi4_sub_if[top_pkg::TlCrossbar].wuser    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].w.user;

    axi4_sub_if[top_pkg::TlCrossbar].arvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar_valid;
    axi4_sub_if[top_pkg::TlCrossbar].arid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.id;
    axi4_sub_if[top_pkg::TlCrossbar].araddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.addr;
    axi4_sub_if[top_pkg::TlCrossbar].arlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.len;
    axi4_sub_if[top_pkg::TlCrossbar].arsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.size;
    axi4_sub_if[top_pkg::TlCrossbar].arburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.burst;
    axi4_sub_if[top_pkg::TlCrossbar].arlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.lock;
    axi4_sub_if[top_pkg::TlCrossbar].arcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.cache;
    axi4_sub_if[top_pkg::TlCrossbar].arprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.prot;
    axi4_sub_if[top_pkg::TlCrossbar].arqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.qos;
    axi4_sub_if[top_pkg::TlCrossbar].arregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.region;
    axi4_sub_if[top_pkg::TlCrossbar].aruser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].ar.user;

    axi4_sub_if[top_pkg::TlCrossbar].bready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].b_ready;
    axi4_sub_if[top_pkg::TlCrossbar].rready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar].r_ready;

    // Response signals (Slave -> XBAR)
    axi4_sub_if[top_pkg::TlCrossbar].awready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].aw_ready;
    axi4_sub_if[top_pkg::TlCrossbar].wready   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].w_ready;
    axi4_sub_if[top_pkg::TlCrossbar].arready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].ar_ready;
    
    axi4_sub_if[top_pkg::TlCrossbar].bvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].b_valid;
    axi4_sub_if[top_pkg::TlCrossbar].bid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].b.id;
    axi4_sub_if[top_pkg::TlCrossbar].bresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].b.resp;
    axi4_sub_if[top_pkg::TlCrossbar].buser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].b.user;

    axi4_sub_if[top_pkg::TlCrossbar].rvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].r_valid;
    axi4_sub_if[top_pkg::TlCrossbar].rid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].r.id;
    axi4_sub_if[top_pkg::TlCrossbar].rdata    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].r.data;
    axi4_sub_if[top_pkg::TlCrossbar].rresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].r.resp;
    axi4_sub_if[top_pkg::TlCrossbar].rlast    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].r.last;
    axi4_sub_if[top_pkg::TlCrossbar].ruser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar].r.user;
  end

  // =========================================================
  // slv3 - Tapping the XBAR Master Port 2 (Slave VIP side)
  // =========================================================
  assign axi4_sub_if[top_pkg::DRAM].aclk    = clk;
  assign axi4_sub_if[top_pkg::DRAM].aresetn = rst_n;

  always_comb begin
    // Request signals (XBAR -> Slave)
    axi4_sub_if[top_pkg::DRAM].awvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw_valid;
    axi4_sub_if[top_pkg::DRAM].awid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.id;
    axi4_sub_if[top_pkg::DRAM].awaddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.addr;
    axi4_sub_if[top_pkg::DRAM].awlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.len;
    axi4_sub_if[top_pkg::DRAM].awsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.size;
    axi4_sub_if[top_pkg::DRAM].awburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.burst;
    axi4_sub_if[top_pkg::DRAM].awlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.lock;
    axi4_sub_if[top_pkg::DRAM].awcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.cache;
    axi4_sub_if[top_pkg::DRAM].awprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.prot;
    axi4_sub_if[top_pkg::DRAM].awqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.qos;
    axi4_sub_if[top_pkg::DRAM].awregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.region;
    axi4_sub_if[top_pkg::DRAM].awuser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].aw.user;

    axi4_sub_if[top_pkg::DRAM].wvalid   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].w_valid;
    axi4_sub_if[top_pkg::DRAM].wdata    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].w.data;
    axi4_sub_if[top_pkg::DRAM].wstrb    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].w.strb;
    axi4_sub_if[top_pkg::DRAM].wlast    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].w.last;
    axi4_sub_if[top_pkg::DRAM].wuser    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].w.user;

    axi4_sub_if[top_pkg::DRAM].arvalid  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar_valid;
    axi4_sub_if[top_pkg::DRAM].arid     = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.id;
    axi4_sub_if[top_pkg::DRAM].araddr   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.addr;
    axi4_sub_if[top_pkg::DRAM].arlen    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.len;
    axi4_sub_if[top_pkg::DRAM].arsize   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.size;
    axi4_sub_if[top_pkg::DRAM].arburst  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.burst;
    axi4_sub_if[top_pkg::DRAM].arlock   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.lock;
    axi4_sub_if[top_pkg::DRAM].arcache  = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.cache;
    axi4_sub_if[top_pkg::DRAM].arprot   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.prot;
    axi4_sub_if[top_pkg::DRAM].arqos    = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.qos;
    axi4_sub_if[top_pkg::DRAM].arregion = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.region;
    axi4_sub_if[top_pkg::DRAM].aruser   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].ar.user;

    axi4_sub_if[top_pkg::DRAM].bready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].b_ready;
    axi4_sub_if[top_pkg::DRAM].rready   = `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM].r_ready;

    // Response signals (Slave -> XBAR)
    axi4_sub_if[top_pkg::DRAM].awready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].aw_ready;
    axi4_sub_if[top_pkg::DRAM].wready   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].w_ready;
    axi4_sub_if[top_pkg::DRAM].arready  = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].ar_ready;
    
    axi4_sub_if[top_pkg::DRAM].bvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].b_valid;
    axi4_sub_if[top_pkg::DRAM].bid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].b.id;
    axi4_sub_if[top_pkg::DRAM].bresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].b.resp;
    axi4_sub_if[top_pkg::DRAM].buser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].b.user;

    axi4_sub_if[top_pkg::DRAM].rvalid   = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].r_valid;
    axi4_sub_if[top_pkg::DRAM].rid      = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].r.id;
    axi4_sub_if[top_pkg::DRAM].rdata    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].r.data;
    axi4_sub_if[top_pkg::DRAM].rresp    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].r.resp;
    axi4_sub_if[top_pkg::DRAM].rlast    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].r.last;
    axi4_sub_if[top_pkg::DRAM].ruser    = `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM].r.user;
  end
