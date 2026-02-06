// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package top_pkg;
  import axi_pkg::*;

  // TileLink parameters
  localparam int TL_AW  = 32;
  localparam int TL_DW  = 32; // = TL_DBW * 8; TL_DBW must be a power-of-two
  localparam int TL_AIW = 8; // a_source, d_source
  localparam int TL_DIW = 1; // d_sink
  localparam int TL_AUW = 23; // a_user
  localparam int TL_DUW = 14; // d_user
  localparam int TL_DBW = (TL_DW>>3);
  localparam int TL_SZW = $clog2($clog2(TL_DBW)+1);

  // AXI crossbar parameters
  localparam int AxiXbarHosts   = 1;
  localparam int AxiXbarDevices = 2;

  // AXI crossbar hosts and devices
  typedef enum int unsigned {
    CVA6 = 0
  } axi_hosts_t;

  typedef enum int unsigned {
    SRAM       = 0,
    TlCrossbar = 1
  } axi_devices_t;

  typedef enum longint unsigned {
    SRAMBase       = 64'h1000_0000,
    TlCrossbarBase = 64'h4000_0000
  } axi_addr_start_t;

  typedef enum longint unsigned {
    SRAMLength       = 64'h0002_0000,
    TlCrossbarLength = 64'h1000_0000
  } axi_addr_length_t;

  typedef enum longint unsigned {
    SRAMMask       = SRAMLength - 1,
    TlCrossbarMask = TlCrossbarLength - 1
  } axi_addr_mask_t;

  // AXI parameters
  localparam AxiIdWidth   = cva6_config_pkg::CVA6ConfigAxiIdWidth;
  localparam AxiUserWidth = cva6_config_pkg::CVA6ConfigDataUserWidth;
  localparam AxiAddrWidth = cva6_config_pkg::CVA6ConfigAxiAddrWidth;
  localparam AxiDataWidth = cva6_config_pkg::CVA6ConfigAxiDataWidth;
  localparam AxiStrbWidth = AxiDataWidth / 8;

  // AXI data types
  typedef logic [AxiIdWidth-1:0]   id_t;
  typedef logic [AxiAddrWidth-1:0] addr_t;
  typedef logic [AxiDataWidth-1:0] data_t;
  typedef logic [AxiStrbWidth-1:0] strb_t;
  typedef logic [AxiUserWidth-1:0] user_t;

  // AW Channel
  typedef struct packed {
    id_t              id;
    addr_t            addr;
    len_t             len;
    axi_pkg::size_t   size;
    axi_pkg::burst_t  burst;
    logic             lock;
    axi_pkg::cache_t  cache;
    axi_pkg::prot_t   prot;
    axi_pkg::qos_t    qos;
    axi_pkg::region_t region;
    axi_pkg::atop_t   atop;
    user_t            user;
  } axi_aw_chan_t;

  // W Channel - AXI4 doesn't define a width
  typedef struct packed {
    data_t data;
    strb_t strb;
    logic  last;
    user_t user;
  } axi_w_chan_t;

  // B Channel
  typedef struct packed {
    id_t            id;
    axi_pkg::resp_t resp;
    user_t          user;
  } axi_b_chan_t;

  // AR Channel
  typedef struct packed {
    id_t              id;
    addr_t            addr;
    axi_pkg::len_t    len;
    axi_pkg::size_t   size;
    axi_pkg::burst_t  burst;
    logic             lock;
    axi_pkg::cache_t  cache;
    axi_pkg::prot_t   prot;
    axi_pkg::qos_t    qos;
    axi_pkg::region_t region;
    user_t            user;
  } axi_ar_chan_t;

  // R Channel
  typedef struct packed {
    id_t            id;
    data_t          data;
    axi_pkg::resp_t resp;
    logic           last;
    user_t          user;
  } axi_r_chan_t;

  // Request/Response structs
  typedef struct packed {
    axi_aw_chan_t aw;
    logic         aw_valid;
    axi_w_chan_t  w;
    logic         w_valid;
    logic         b_ready;
    axi_ar_chan_t ar;
    logic         ar_valid;
    logic         r_ready;
  } axi_req_t;

  typedef struct packed {
    logic        aw_ready;
    logic        ar_ready;
    logic        w_ready;
    logic        b_valid;
    axi_b_chan_t b;
    logic        r_valid;
    axi_r_chan_t r;
  } axi_resp_t;

endpackage
