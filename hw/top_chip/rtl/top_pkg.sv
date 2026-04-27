// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "axi/typedef.svh"

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
  localparam int AxiXbarDevices = 5;

  // AXI crossbar hosts and devices
  typedef enum int unsigned {
    CVA6 = 0
  } axi_hosts_t;

  typedef enum int unsigned {
    RomCtrlMem = 0,
    SRAM       = 1,
    Mailbox    = 2,
    TlCrossbar = 3,
    DRAM       = 4
  } axi_devices_t;

  typedef enum longint unsigned {
    RomCtrlMemBase = 64'h0008_0000,
    SRAMBase       = 64'h1000_0000,
    MailboxBase    = 64'h2001_0000,
    TlCrossbarBase = 64'h4000_0000,
    DRAMBase       = 64'h8000_0000
  } axi_addr_start_t;

  // Memory lengths
  localparam longint unsigned RomCtrlMemLength   = 64'h0000_8000;
  localparam longint unsigned SRAMLength         = 64'h0002_0000;
  localparam longint unsigned MailboxLength      = 64'h0001_0000;
  localparam longint unsigned TlCrossbarLength   = 64'h1000_0000;
  localparam longint unsigned DRAMPhysicalLength = 64'h4000_0000;

  // Memory address masks
  localparam longint unsigned RomCtrlMemMask = RomCtrlMemLength - 1;
  localparam longint unsigned SRAMMask       = SRAMLength - 1;
  localparam longint unsigned MailboxMask    = MailboxLength - 1;
  localparam longint unsigned TlCrossbarMask = TlCrossbarLength - 1;
  localparam longint unsigned DRAMMask       = DRAMPhysicalLength - 1;

  // Tag controller parameters
  localparam int     unsigned CapSizeBits              = 128;
  localparam longint unsigned TagCacheMemLength        = DRAMPhysicalLength >> $clog2(CapSizeBits);
  localparam longint unsigned DRAMUsableLength         = DRAMPhysicalLength - TagCacheMemLength;
  localparam longint unsigned TagCacheMemBase          = DRAMBase + DRAMUsableLength;
  localparam int     unsigned TagCacheSetAssociativity = 8;
  localparam int     unsigned TagCacheNumLines         = 128; // Number of cache lines in each set
  localparam int     unsigned TagCacheNumBlocks        = 4;   // Number of words in a cache line

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
