// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package top_bus_pkg;
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
    DebugMemBase   = 64'h2000_0000,
    MailboxBase    = 64'h2001_0000,
    TlCrossbarBase = 64'h4000_0000,
    DRAMBase       = 64'h8000_0000
  } axi_addr_start_t;

  // Memory lengths
  localparam longint unsigned RomCtrlMemLength   = 64'h0000_8000;
  localparam longint unsigned SRAMLength         = 64'h0002_0000;
  localparam longint unsigned DebugMemLength     = 64'h0000_1000;
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
endpackage
