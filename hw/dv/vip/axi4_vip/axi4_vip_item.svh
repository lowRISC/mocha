// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class axi4_vip_item extends uvm_sequence_item;

  axi_obs_e obs_kind;
  axi_dir_e dir;

  bit [`AXI4_MAX_ID_WIDTH-1:0]     awid;
  bit [`AXI4_MAX_ADDR_WIDTH-1:0]   awaddr;
  bit [7:0]                        awlen;
  bit [2:0]                        awsize;
  bit [1:0]                        awburst;
  bit                              awlock;
  bit [3:0]                        awcache;
  bit [2:0]                        awprot;
  bit [`AXI4_MAX_QOS_WIDTH-1:0]    awqos;
  bit [`AXI4_MAX_REGION_WIDTH-1:0] awregion;
  bit [`AXI4_MAX_USER_WIDTH-1:0]   awuser;

  bit [`AXI4_MAX_DATA_WIDTH-1:0]   wdata[$];
  bit [`AXI4_MAX_DATA_WIDTH/8-1:0] wstrb[$];
  bit                              wlast[$];
  bit [`AXI4_MAX_USER_WIDTH-1:0]   wuser[$];

  bit [`AXI4_MAX_ID_WIDTH-1:0]     bid;
  bit [1:0]                        bresp;
  bit [`AXI4_MAX_USER_WIDTH-1:0]   buser;

  bit [`AXI4_MAX_ID_WIDTH-1:0]     arid;
  bit [`AXI4_MAX_ADDR_WIDTH-1:0]   araddr;
  bit [7:0]                        arlen;
  bit [2:0]                        arsize;
  bit [1:0]                        arburst;
  bit                              arlock;
  bit [3:0]                        arcache;
  bit [2:0]                        arprot;
  bit [`AXI4_MAX_QOS_WIDTH-1:0]    arqos;
  bit [`AXI4_MAX_REGION_WIDTH-1:0] arregion;
  bit [`AXI4_MAX_USER_WIDTH-1:0]   aruser;

  bit [`AXI4_MAX_ID_WIDTH-1:0]     rid;
  bit [`AXI4_MAX_DATA_WIDTH-1:0]   rdata[$];
  bit [1:0]                        rresp[$];
  bit                              rlast[$];
  bit [`AXI4_MAX_USER_WIDTH-1:0]   ruser[$];

  `uvm_object_utils_begin(axi4_vip_item)
    `uvm_field_enum(axi_obs_e, obs_kind, UVM_DEFAULT)
    `uvm_field_enum(axi_dir_e, dir, UVM_DEFAULT)

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

  // Clone and return the result as axi4_vip_item.
  extern virtual function axi4_vip_item item_clone();

endclass : axi4_vip_item

function axi4_vip_item::new(string name = "");
  super.new(name);
endfunction : new

function axi4_vip_item axi4_vip_item::item_clone();
  $cast(item_clone, clone());
endfunction : item_clone
