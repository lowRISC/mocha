// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef __AXI4_VIP_IF_SV
`define __AXI4_VIP_IF_SV

interface axi4_vip_if #(
  parameter int ID_WIDTH     = 4,
  parameter int ADDR_WIDTH   = 32,
  parameter int DATA_WIDTH   = 64,
  parameter int USER_WIDTH   = 8,
  parameter int REGION_WIDTH = 4,
  parameter int QOS_WIDTH    = 4
)(
  input  logic aclk,
  input  logic aresetn
);

  // =========================================================
  // write address channel
  // =========================================================
  logic                      awvalid;
  logic                      awready;
  logic [ID_WIDTH-1:0]       awid;
  logic [ADDR_WIDTH-1:0]     awaddr;
  logic [7:0]                awlen;
  logic [2:0]                awsize;
  logic [1:0]                awburst;
  logic                      awlock;
  logic [3:0]                awcache;
  logic [2:0]                awprot;
  logic [QOS_WIDTH-1:0]      awqos;
  logic [REGION_WIDTH-1:0]   awregion;
  logic [USER_WIDTH-1:0]     awuser;

  // =========================================================
  // write data channel
  // =========================================================
  logic                      wvalid;
  logic                      wready;
  logic [DATA_WIDTH-1:0]     wdata;
  logic [(DATA_WIDTH/8)-1:0] wstrb;
  logic                      wlast;
  logic [USER_WIDTH-1:0]     wuser;

  // =========================================================
  // write response channel
  // =========================================================
  logic                      bvalid;
  logic                      bready;
  logic [ID_WIDTH-1:0]       bid;
  logic [1:0]                bresp;
  logic [USER_WIDTH-1:0]     buser;

  // =========================================================
  // read address channel
  // =========================================================
  logic                      arvalid;
  logic                      arready;
  logic [ID_WIDTH-1:0]       arid;
  logic [ADDR_WIDTH-1:0]     araddr;
  logic [7:0]                arlen;
  logic [2:0]                arsize;
  logic [1:0]                arburst;
  logic                      arlock;
  logic [3:0]                arcache;
  logic [2:0]                arprot;
  logic [QOS_WIDTH-1:0]      arqos;
  logic [REGION_WIDTH-1:0]   arregion;
  logic [USER_WIDTH-1:0]     aruser;

  // =========================================================
  // read data channel
  // =========================================================
  logic                      rvalid;
  logic                      rready;
  logic [ID_WIDTH-1:0]       rid;
  logic [DATA_WIDTH-1:0]     rdata;
  logic [1:0]                rresp;
  logic                      rlast;
  logic [USER_WIDTH-1:0]     ruser;

  // master clocking block
  clocking master_cb @(posedge aclk);

    // write address
    output awvalid, awid, awaddr, awlen, awsize, awburst;
    output awlock, awcache, awprot, awqos, awregion, awuser;
    input  awready;

    // write data
    output wvalid, wdata, wstrb, wlast, wuser;
    input  wready;

    // write response
    input  bvalid, bid, bresp, buser;
    output bready;

    // read address
    output arvalid, arid, araddr, arlen, arsize, arburst;
    output arlock, arcache, arprot, arqos, arregion, aruser;
    input  arready;

    // read data
    input  rvalid, rid, rdata, rresp, rlast, ruser;
    output rready;

  endclocking


  // slave clocking block
  clocking slave_cb @(posedge aclk);

    // write address
    input  awvalid, awid, awaddr, awlen, awsize, awburst;
    input  awlock, awcache, awprot, awqos, awregion, awuser;
    output awready;

    // write data
    input  wvalid, wdata, wstrb, wlast, wuser;
    output wready;

    // write response
    output bvalid, bid, bresp, buser;
    input  bready;

    // read address
    input  arvalid, arid, araddr, arlen, arsize, arburst;
    input  arlock, arcache, arprot, arqos, arregion, aruser;
    output arready;

    // read data
    output rvalid, rid, rdata, rresp, rlast, ruser;
    input  rready;

  endclocking


  // monitor clocking block
  clocking monitor_cb @(posedge aclk);

    input awvalid, awready, awid, awaddr, awlen, awsize, awburst;
    input awlock, awcache, awprot, awqos, awregion, awuser;

    input wvalid, wready, wdata, wstrb, wlast, wuser;

    input bvalid, bready, bid, bresp, buser;

    input arvalid, arready, arid, araddr, arlen, arsize, arburst;
    input arlock, arcache, arprot, arqos, arregion, aruser;

    input rvalid, rready, rid, rdata, rresp, rlast, ruser;

  endclocking

endinterface

`endif // __AXI4_VIP_IF_SV