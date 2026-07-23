// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitored AXI read transaction: the read address (AR) and the read data beats (R).
// Emitted partial on ar_ap (AR only) and r_ap (R beats only); fully merged on tx_ap.
// Field widths mirror the axi_*_if max footprint.

class axi_mon_read_item extends axi_mon_item;

  // Read address (AR)
  bit [31:0]   arid;
  bit [63:0]   araddr;
  bit [7:0]    arlen;
  bit [2:0]    arsize;
  bit [1:0]    arburst;
  bit          arlock;
  bit [3:0]    arcache;
  bit [2:0]    arprot;
  bit [3:0]    arqos;
  bit [3:0]    arregion;
  bit [127:0]  aruser;

  // Read data (R) — one entry per beat
  bit [31:0]   rid;
  bit [1023:0] rdata[$];
  bit [2:0]    rresp[$];
  bit          rlast[$];
  bit [527:0]  ruser[$];

  `uvm_object_utils_begin(axi_mon_read_item)
    // Read Address
    `uvm_field_int(arid, UVM_DEFAULT)
    `uvm_field_int(araddr, UVM_DEFAULT)
    `uvm_field_int(arlen, UVM_DEFAULT)
    `uvm_field_int(arsize, UVM_DEFAULT)
    `uvm_field_int(arburst, UVM_DEFAULT)
    `uvm_field_int(arlock, UVM_DEFAULT)
    `uvm_field_int(arcache, UVM_DEFAULT)
    `uvm_field_int(arprot, UVM_DEFAULT)
    `uvm_field_int(arqos, UVM_DEFAULT)
    `uvm_field_int(arregion, UVM_DEFAULT)
    `uvm_field_int(aruser, UVM_DEFAULT)

    // Read Data (Queues)
    `uvm_field_int(rid, UVM_DEFAULT)
    `uvm_field_queue_int(rdata, UVM_DEFAULT)
    `uvm_field_queue_int(rresp, UVM_DEFAULT)
    `uvm_field_queue_int(rlast, UVM_DEFAULT)
    `uvm_field_queue_int(ruser, UVM_DEFAULT)
  `uvm_object_utils_end

  extern function new(string name = "");

  extern virtual function bit [31:0]  get_id();
  extern virtual function bit [63:0]  get_addr();
  extern virtual function axi_dir_e   get_dir();
  extern virtual function string      convert2string();

endclass : axi_mon_read_item

function axi_mon_read_item::new(string name = "");
  super.new(name);
endfunction : new

function bit [31:0] axi_mon_read_item::get_id();
  return arid;
endfunction : get_id

function bit [63:0] axi_mon_read_item::get_addr();
  return araddr;
endfunction : get_addr

function axi_dir_e axi_mon_read_item::get_dir();
  return AXI_READ;
endfunction : get_dir

function string axi_mon_read_item::convert2string();
  return $sformatf("READ id=%0h addr=%0h len=%0d size=%0d burst=%0d beats=%0d",
                   arid, araddr, arlen, arsize, arburst, rdata.size());
endfunction : convert2string
