// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`define AXI4_VIP_CONNECT_CLK_RST(dst) \
  assign dst.aclk    = clk;           \
  assign dst.aresetn = rst_n

`define AXI4_VIP_CONNECT_REQ(dst, src) \
  assign dst.awvalid  = src.aw_valid;  \
  assign dst.awid     = src.aw.id;     \
  assign dst.awaddr   = src.aw.addr;   \
  assign dst.awlen    = src.aw.len;    \
  assign dst.awsize   = src.aw.size;   \
  assign dst.awburst  = src.aw.burst;  \
  assign dst.awlock   = src.aw.lock;   \
  assign dst.awcache  = src.aw.cache;  \
  assign dst.awprot   = src.aw.prot;   \
  assign dst.awqos    = src.aw.qos;    \
  assign dst.awregion = src.aw.region; \
  assign dst.awuser   = src.aw.user;   \
  assign dst.wvalid   = src.w_valid;   \
  assign dst.wdata    = src.w.data;    \
  assign dst.wstrb    = src.w.strb;    \
  assign dst.wlast    = src.w.last;    \
  assign dst.wuser    = src.w.user;    \
  assign dst.arvalid  = src.ar_valid;  \
  assign dst.arid     = src.ar.id;     \
  assign dst.araddr   = src.ar.addr;   \
  assign dst.arlen    = src.ar.len;    \
  assign dst.arsize   = src.ar.size;   \
  assign dst.arburst  = src.ar.burst;  \
  assign dst.arlock   = src.ar.lock;   \
  assign dst.arcache  = src.ar.cache;  \
  assign dst.arprot   = src.ar.prot;   \
  assign dst.arqos    = src.ar.qos;    \
  assign dst.arregion = src.ar.region; \
  assign dst.aruser   = src.ar.user;   \
  assign dst.bready   = src.b_ready;   \
  assign dst.rready   = src.r_ready

`define AXI4_VIP_CONNECT_RESP(dst, src) \
  assign dst.awready = src.aw_ready;    \
  assign dst.wready  = src.w_ready;     \
  assign dst.arready = src.ar_ready;    \
  assign dst.bvalid  = src.b_valid;     \
  assign dst.bid     = src.b.id;        \
  assign dst.bresp   = src.b.resp;      \
  assign dst.buser   = src.b.user;      \
  assign dst.rvalid  = src.r_valid;     \
  assign dst.rid     = src.r.id;        \
  assign dst.rdata   = src.r.data;      \
  assign dst.rresp   = src.r.resp;      \
  assign dst.rlast   = src.r.last;      \
  assign dst.ruser   = src.r.user

`define AXI4_VIP_CONNECT_IF(dst, req, rsp) \
  `AXI4_VIP_CONNECT_CLK_RST(dst);          \
  `AXI4_VIP_CONNECT_REQ(dst, req);         \
  `AXI4_VIP_CONNECT_RESP(dst, rsp);

`AXI4_VIP_CONNECT_IF(axi4_mgr_if[top_pkg::CVA6],
                     `AXI_XBAR_HIER.slv_ports_req_i[top_pkg::CVA6],
                     `AXI_XBAR_HIER.slv_ports_resp_o[top_pkg::CVA6])

`AXI4_VIP_CONNECT_IF(axi4_sub_if[top_pkg::RomCtrlMem],
                     `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::RomCtrlMem],
                     `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::RomCtrlMem])

`AXI4_VIP_CONNECT_IF(axi4_sub_if[top_pkg::SRAM],
                     `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::SRAM],
                     `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::SRAM])

`AXI4_VIP_CONNECT_IF(axi4_sub_if[top_pkg::Mailbox],
                     `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::Mailbox],
                     `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::Mailbox])

`AXI4_VIP_CONNECT_IF(axi4_sub_if[top_pkg::TlCrossbar],
                     `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::TlCrossbar],
                     `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::TlCrossbar])

`AXI4_VIP_CONNECT_IF(axi4_sub_if[top_pkg::DRAM],
                     `AXI_XBAR_HIER.mst_ports_req_o[top_pkg::DRAM],
                     `AXI_XBAR_HIER.mst_ports_resp_i[top_pkg::DRAM])

`undef AXI4_VIP_CONNECT_IF
`undef AXI4_VIP_CONNECT_RESP
`undef AXI4_VIP_CONNECT_REQ
`undef AXI4_VIP_CONNECT_CLK_RST
