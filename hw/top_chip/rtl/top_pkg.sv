// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "axi/typedef.svh"

package top_pkg;
  import axi_pkg::*;

  import top_bus_pkg::*;

  // AXI parameters
  localparam AxiIdWidth   = cva6_config_pkg::CVA6ConfigAxiIdWidth;
  localparam AxiUserWidth = cva6_config_pkg::CVA6ConfigDataUserWidth;
  localparam AxiAddrWidth = cva6_config_pkg::CVA6ConfigAxiAddrWidth;
  localparam AxiDataWidth = cva6_config_pkg::CVA6ConfigAxiDataWidth;
  localparam AxiStrbWidth = AxiDataWidth / 8;

  // AXI data types
  typedef logic [AxiIdWidth-1:0]   id_t;
  typedef logic [AxiIdWidth:0]     id_dram_t; // Tag controller DRAM-side ID, which is 1 bit wider
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

  // Tag controller DRAM-side AXI channel types
  typedef struct packed {
    id_dram_t         id;
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
  } axi_dram_aw_chan_t;

  typedef struct packed {
    id_dram_t       id;
    axi_pkg::resp_t resp;
    user_t          user;
  } axi_dram_b_chan_t;

  typedef struct packed {
    id_dram_t         id;
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
  } axi_dram_ar_chan_t;

  typedef struct packed {
    id_dram_t       id;
    data_t          data;
    axi_pkg::resp_t resp;
    logic           last;
    user_t          user;
  } axi_dram_r_chan_t;

  // Tag controller DRAM-side AXI request/response structs
  typedef struct packed {
    axi_dram_aw_chan_t aw;
    logic              aw_valid;
    axi_w_chan_t       w;
    logic              w_valid;
    logic              b_ready;
    axi_dram_ar_chan_t ar;
    logic              ar_valid;
    logic              r_ready;
  } axi_dram_req_t;

  typedef struct packed {
    logic             aw_ready;
    logic             ar_ready;
    logic             w_ready;
    logic             b_valid;
    axi_dram_b_chan_t b;
    logic             r_valid;
    axi_dram_r_chan_t r;
  } axi_dram_resp_t;

  // Base Address Mailbox over ext AXI port
  localparam addr_t MailboxExtBaseAddr = 'h0000_0000_0000_1000;

  // AXI Lite type definitions
  `AXI_LITE_TYPEDEF_ALL(axi_lite, addr_t, data_t, strb_t)

endpackage
