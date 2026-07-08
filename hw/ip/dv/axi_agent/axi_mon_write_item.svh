// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitored AXI write transaction: the write address (AW), the write data beats (W)
// and the write response (B). Emitted partial on aw_ap (AW only) and w_ap (W beats
// only); fully merged on tx_ap. Field widths mirror the axi_*_if max footprint.

class axi_mon_write_item extends axi_mon_item;

  // Write address (AW)
  bit [31:0]   awid;
  bit [63:0]   awaddr;
  bit [7:0]    awlen;
  bit [2:0]    awsize;
  bit [1:0]    awburst;
  bit          awlock;
  bit [3:0]    awcache;
  bit [2:0]    awprot;
  bit [3:0]    awqos;
  bit [3:0]    awregion;
  bit [127:0]  awuser;

  // Write data (W) — one entry per beat
  bit [1023:0] wdata[$];
  bit [127:0]  wstrb[$];
  bit          wlast[$];
  bit [511:0]  wuser[$];

  // Write response (B)
  bit [31:0]   bid;
  bit [2:0]    bresp;
  bit [15:0]   buser;

  `uvm_object_utils_begin(axi_mon_write_item)
    // Write Address
    `uvm_field_int(awid, UVM_DEFAULT)
    `uvm_field_int(awaddr, UVM_DEFAULT)
    `uvm_field_int(awlen, UVM_DEFAULT)
    `uvm_field_int(awsize, UVM_DEFAULT)
    `uvm_field_int(awburst, UVM_DEFAULT)
    `uvm_field_int(awlock, UVM_DEFAULT)
    `uvm_field_int(awcache, UVM_DEFAULT)
    `uvm_field_int(awprot, UVM_DEFAULT)
    `uvm_field_int(awqos, UVM_DEFAULT)
    `uvm_field_int(awregion, UVM_DEFAULT)
    `uvm_field_int(awuser, UVM_DEFAULT)

    // Write Data (Queues)
    `uvm_field_queue_int(wdata, UVM_DEFAULT)
    `uvm_field_queue_int(wstrb, UVM_DEFAULT)
    `uvm_field_queue_int(wlast, UVM_DEFAULT)
    `uvm_field_queue_int(wuser, UVM_DEFAULT)

    // Write Response
    `uvm_field_int(bid, UVM_DEFAULT)
    `uvm_field_int(bresp, UVM_DEFAULT)
    `uvm_field_int(buser, UVM_DEFAULT)
  `uvm_object_utils_end

  extern function new(string name = "");

  extern virtual function bit [31:0]  get_id();
  extern virtual function bit [63:0]  get_addr();
  extern virtual function axi_dir_e   get_dir();
  extern virtual function string      convert2string();

endclass : axi_mon_write_item

function axi_mon_write_item::new(string name = "");
  super.new(name);
endfunction : new

function bit [31:0] axi_mon_write_item::get_id();
  return awid;
endfunction : get_id

function bit [63:0] axi_mon_write_item::get_addr();
  return awaddr;
endfunction : get_addr

function axi_dir_e axi_mon_write_item::get_dir();
  return AXI_WRITE;
endfunction : get_dir

function string axi_mon_write_item::convert2string();
  return $sformatf("WRITE id=%0h addr=%0h len=%0d size=%0d burst=%0d beats=%0d bresp=%0h",
                   awid, awaddr, awlen, awsize, awburst, wdata.size(), bresp);
endfunction : convert2string
