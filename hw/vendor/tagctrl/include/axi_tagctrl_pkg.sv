// Copyright 2023 Bruno Sá and Zero-Day Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   07.12.2023

/// Contains the configuration and internal messages structs of the `axi_tagctrl`.
/// Parameter contained in this package are for fine grain configuration of the modules.
/// They can be changed to adapt the cache to a specific design for optimal performance.
package axi_tagctrl_pkg;
  /// Version parameter, can be read out from configuration port.
  ///
  /// This is ASCII encoded after the semantic versioning: `vAA.BB.C`
  parameter logic [63:0] AxiTagCtrlVersion = 64'h7630_302E_3030_2E31;
  parameter logic [3:0] AxReqId = 4'b1011;

  /// Tag Controller configuration struct.
  /// Automatically set in (module.axi_llc_top).
  typedef struct packed {
    /// AXI4+ATOP ID width of the slave port from CPU side
    int unsigned AxiIdWidth;
    /// AXI4+ATOP address width of the slave port from CPU side
    int unsigned AxiAddrWidth;
    /// AXI4+ATOP data width of the slave port from CPU side
    int unsigned AxiDataWidth;
    /// Capability size in memory
    int unsigned CapSize;
    /// DRAM memory Base
    int unsigned DRAMMemBase;
    /// DRAM memory Length
    int unsigned DRAMMemLength;
    /// Tag Cache base address in memory. Location of the Tag Cache
    /// structure
    int unsigned TagCacheMemBase;
    /// Tag controller write FIFO depth
    int unsigned TagWFifoDepth;
    /// Tag controller AX FIFO depth
    int unsigned TagAXFifoDepth;
    /// Tag controller read FIFO from memory depth
    int unsigned TagRFifoDepth;
    /// Tag Cache config structure
    axi_llc_pkg::llc_cfg_t tagc_cfg;
  } tagctrl_cfg_t;

endpackage
