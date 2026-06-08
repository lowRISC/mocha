// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "axi/typedef.svh"

package top_pkg;
  import axi_pkg::*;

  ////////////////////////////////////////////
  // ROM Scrambling Parameters
  // CRITICAL: CHANGE THE SECRET VALUES BELOW BEFORE ANY REAL-WORLD DEPLOYMENT!
  ////////////////////////////////////////////
  // Fixed nonce used for address / data scrambling
  parameter bit [63:0] RndCnstRomCtrlScrNonce = {
    64'hD35500E5_A51BBA34
  };
  // Randomised constant used as a scrambling key for ROM data
  parameter bit [127:0] RndCnstRomCtrlScrKey = {
    128'hA71D81E9_EB876B6F_1996B2BE_4B58DFCF
  };
  ////////////////////////////////////////////

  // TileLink parameters
  localparam int TL_AW  = 32;
  localparam int TL_DW  = 32; // = TL_DBW * 8; TL_DBW must be a power-of-two
  localparam int TL_AIW = 8; // a_source, d_source
  localparam int TL_DIW = 1; // d_sink
  localparam int TL_AUW = 23; // a_user
  localparam int TL_DUW = 14; // d_user
  localparam int TL_DBW = (TL_DW>>3);
  localparam int TL_SZW = $clog2($clog2(TL_DBW)+1);

  // Mocha AXI crossbar parameters
  localparam int AxiXbarHosts   = 2;
  localparam int AxiXbarDevices = 7;

  // Mocha AXI crossbar hosts and devices
  typedef enum int unsigned {
    CVA6 = 0,
    DM_HOST = 1
  } axi_hosts_t;

  typedef enum int unsigned {
    RomCtrlMem = 0,
    SRAM       = 1,
    DM_DEV     = 2,
    Mailbox    = 3,
    RestOfChip = 4,
    TlCrossbar = 5,
    DRAM       = 6
  } axi_devices_t;

  parameter int unsigned DebugMemBase32 = 32'h2000_0000;

  typedef enum longint unsigned {
    RomCtrlMemBase = 64'h0008_0000,
    SRAMBase       = 64'h1000_0000,
    DebugMemBase   = {32'h0, DebugMemBase32},
    MailboxBase    = 64'h2001_0000,
    RestOfChipBase = 64'h3000_0000,
    TlCrossbarBase = 64'h4000_0000,
    DRAMBase       = 64'h8000_0000
  } axi_addr_start_t;

  // Memory lengths
  localparam longint unsigned RomCtrlMemLength   = 64'h0000_8000;
  localparam longint unsigned SRAMLength         = 64'h0002_0000;
  localparam longint unsigned DebugMemLength     = 64'h0000_1000;
  localparam longint unsigned MailboxLength      = 64'h0001_0000;
  localparam longint unsigned RestOfChipLength   = 64'h0000_8000;
  localparam longint unsigned TlCrossbarLength   = 64'h1000_0000;
  localparam longint unsigned DRAMPhysicalLength = 64'h4000_0000;

  // Memory address masks
  localparam longint unsigned RomCtrlMemMask = RomCtrlMemLength - 1;
  localparam longint unsigned SRAMMask       = SRAMLength - 1;
  localparam longint unsigned MailboxMask    = MailboxLength - 1;
  localparam longint unsigned RestOfChipMask = RestOfChipLength - 1;
  localparam longint unsigned TlCrossbarMask = TlCrossbarLength - 1;
  localparam longint unsigned DRAMMask       = DRAMPhysicalLength - 1;

  // Rest of chip AXI crossbar parameters
  localparam int RestOfChipAxiXbarHosts   = 1;
  localparam int RestOfChipAxiXbarDevices = 1;

  // Rest of chip AXI crossbar hosts and devices
  typedef enum int unsigned {
    MochaAXICrossbar = 0
  } rest_of_chip_axi_hosts_t;

  typedef enum int unsigned {
    Ethernet = 0
  } rest_of_chip_axi_devices_t;

  typedef enum longint unsigned {
    EthernetBase = 64'h3000_0000
  } rest_of_chip_axi_addr_start_t;

  // Memory lengths
  localparam longint unsigned EthernetLength = 64'h0000_8000;

  // Memory address masks
  localparam longint unsigned EthernetMask = EthernetLength - 1;

  // Entropy source parameters
  localparam int EntropySrcRngBusWidth           = 16;
  localparam int EntropySrcRngBusBitSelWidth     = 4;
  localparam int EntropySrcHealthTestWindowWidth = 20;
  localparam int EntropySrcEsFifoDepth           = 3;
  localparam int EntropySrcDistrFifoDepth        = 11;

  // Tag controller parameters
  localparam int     unsigned CapSizeBits              = 128;
  localparam longint unsigned TagCacheMemLength        = DRAMPhysicalLength >> $clog2(CapSizeBits);
  localparam longint unsigned DRAMUsableLength         = DRAMPhysicalLength - TagCacheMemLength;
  localparam longint unsigned TagCacheMemBase          = DRAMBase + DRAMUsableLength;
  localparam int     unsigned TagCacheSetAssociativity = 8;
  localparam int     unsigned TagCacheNumLines         = 128; // Number of cache lines in each set
  localparam int     unsigned TagCacheNumBlocks        = 4;   // Number of words in a cache line

  // AXI parameters
  localparam AxiIdWidth     = cva6_config_pkg::CVA6ConfigAxiIdWidth;  // Primary crossbar host-side ID
  localparam AxiDevIdWidth  = AxiIdWidth + $clog2(AxiXbarHosts);      // Primary crossbar device-side ID
  localparam AxiDramIdWidth = AxiDevIdWidth + 1;                      // Tag controller DRAM-side ID
  localparam AxiUserWidth   = cva6_config_pkg::CVA6ConfigDataUserWidth;
  localparam AxiAddrWidth   = cva6_config_pkg::CVA6ConfigAxiAddrWidth;
  localparam AxiDataWidth   = cva6_config_pkg::CVA6ConfigAxiDataWidth;
  localparam AxiStrbWidth   = AxiDataWidth / 8;

  // AXI data types
  typedef logic [AxiIdWidth-1:0]     id_t;
  typedef logic [AxiDevIdWidth-1:0]  id_dev_t;
  typedef logic [AxiDramIdWidth-1:0] id_dram_t;
  typedef logic [AxiAddrWidth-1:0]   addr_t;
  typedef logic [AxiDataWidth-1:0]   data_t;
  typedef logic [AxiStrbWidth-1:0]   strb_t;
  typedef logic [AxiUserWidth-1:0]   user_t;

  // Primary crossbar host-side AXI channel types
  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_chan_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_b_chan_t, id_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_chan_t, addr_t, id_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_chan_t, data_t, id_t, user_t)

  // Primary crossbar host-side AXI request/response structs
  `AXI_TYPEDEF_REQ_T(axi_req_t, axi_aw_chan_t, axi_w_chan_t, axi_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_resp_t, axi_b_chan_t, axi_r_chan_t)

  // Primary crossbar device-side AXI channel types
  // axi_dev_w_chan_t not defined because axi_w_chan_t can be used
  `AXI_TYPEDEF_AW_CHAN_T(axi_dev_aw_chan_t, addr_t, id_dev_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_dev_b_chan_t, id_dev_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_dev_ar_chan_t, addr_t, id_dev_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_dev_r_chan_t, data_t, id_dev_t, user_t)

  // Primary crossbar device-side AXI request/response structs
  `AXI_TYPEDEF_REQ_T(axi_dev_req_t, axi_dev_aw_chan_t, axi_w_chan_t, axi_dev_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_dev_resp_t, axi_dev_b_chan_t, axi_dev_r_chan_t)

  // Tag controller DRAM-side AXI channel types
  // axi_dram_w_chan_t not defined because axi_w_chan_t can be used
  `AXI_TYPEDEF_AW_CHAN_T(axi_dram_aw_chan_t, addr_t, id_dram_t, user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_dram_b_chan_t, id_dram_t, user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_dram_ar_chan_t, addr_t, id_dram_t, user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_dram_r_chan_t, data_t, id_dram_t, user_t)

  // Tag controller DRAM-side AXI request/response structs
  `AXI_TYPEDEF_REQ_T(axi_dram_req_t, axi_dram_aw_chan_t, axi_w_chan_t, axi_dram_ar_chan_t)
  `AXI_TYPEDEF_RESP_T(axi_dram_resp_t, axi_dram_b_chan_t, axi_dram_r_chan_t)

  // Base Address Mailbox over ext AXI port
  localparam addr_t MailboxExtBaseAddr = 'h0000_0000_0000_1000;

  // AXI Lite type definitions
  `AXI_LITE_TYPEDEF_ALL(axi_lite, addr_t, data_t, strb_t)

endpackage
