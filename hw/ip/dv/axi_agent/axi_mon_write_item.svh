// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitored AXI write transaction: the write address (AW), the write data beats (W)
// and the write response (B). Published on tx_ap once complete.

class axi_mon_write_item extends axi_mon_item;
  `uvm_object_utils(axi_mon_write_item)

  // All varaibles are 4-state so X values can reach any potential checkers
  // Write address (AW)
  axi_id_t                        m_awid;
  axi_addr_t                      m_awaddr;
  logic [AxiLenWidth-1:0]         m_awlen;
  logic [AxiSizeWidth-1:0]        m_awsize;
  logic [AxiBurstWidth-1:0]       m_awburst;
  logic                           m_awlock;
  logic [AxiCacheWidth-1:0]       m_awcache;
  logic [AxiProtWidth-1:0]        m_awprot;
  logic [AxiQosWidth-1:0]         m_awqos;
  logic [AxiRegionWidth-1:0]      m_awregion;
  logic [AxiMaxReqUserWidth-1:0]  m_awuser;

  // Write data (W) — one entry per beat. WLAST is not stored: the monitor ends the burst on it,
  // so the beat count is m_wdata.size().
  logic [AxiMaxDataWidth-1:0]     m_wdata[$];
  logic [AxiMaxStrbWidth-1:0]     m_wstrb[$];
  logic [AxiMaxDataUserWidth-1:0] m_wuser[$];

  // Write response (B)
  axi_id_t                        m_bid;
  logic [AxiRespWidth-1:0]        m_bresp;
  logic [AxiMaxRespUserWidth-1:0] m_buser;

  extern function new(string name = "");
  extern function void do_print(uvm_printer printer);
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);

  extern virtual function axi_id_t   get_id();
  extern virtual function axi_addr_t get_addr();
  extern virtual function axi_dir_e  get_dir();
  extern virtual function string     convert2string();

endclass : axi_mon_write_item

function axi_mon_write_item::new(string name = "");
  super.new(name);
endfunction : new

function void axi_mon_write_item::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_field_int("m_awid", m_awid, AxiMaxIdWidth, UVM_HEX);
  printer.print_field("m_awaddr", m_awaddr, AxiMaxAddrWidth, UVM_HEX);
  printer.print_field_int("m_awlen", m_awlen, AxiLenWidth, UVM_DEC);
  printer.print_field_int("m_awsize", m_awsize, AxiSizeWidth, UVM_DEC);
  printer.print_field_int("m_awburst", m_awburst, AxiBurstWidth, UVM_BIN);
  printer.print_field_int("m_awlock", m_awlock, 1, UVM_BIN);
  printer.print_field_int("m_awcache", m_awcache, AxiCacheWidth, UVM_BIN);
  printer.print_field_int("m_awprot", m_awprot, AxiProtWidth, UVM_BIN);
  printer.print_field_int("m_awqos", m_awqos, AxiQosWidth, UVM_HEX);
  printer.print_field_int("m_awregion", m_awregion, AxiRegionWidth, UVM_HEX);
  printer.print_field("m_awuser", m_awuser, AxiMaxReqUserWidth, UVM_HEX);
  foreach (m_wdata[i]) begin
    printer.print_field($sformatf("m_wdata[%0d]", i), m_wdata[i], AxiMaxDataWidth, UVM_HEX);
  end
  foreach (m_wstrb[i]) begin
    printer.print_field($sformatf("m_wstrb[%0d]", i), m_wstrb[i], AxiMaxStrbWidth, UVM_HEX);
  end
  foreach (m_wuser[i]) begin
    printer.print_field($sformatf("m_wuser[%0d]", i), m_wuser[i], AxiMaxDataUserWidth, UVM_HEX);
  end
  printer.print_field_int("m_bid", m_bid, AxiMaxIdWidth, UVM_HEX);
  printer.print_field_int("m_bresp", m_bresp, AxiRespWidth, UVM_HEX);
  printer.print_field_int("m_buser", m_buser, AxiMaxRespUserWidth, UVM_HEX);
endfunction

function void axi_mon_write_item::do_copy(uvm_object rhs);
  axi_mon_write_item rhs_;

  if (rhs == null) `uvm_fatal("do_copy", "Cannot copy from RHS: it is null.")
  if (!$cast(rhs_, rhs)) `uvm_fatal("do_copy", "Cannot cast RHS: wrong type?")

  super.do_copy(rhs);
  this.m_awid     = rhs_.m_awid;
  this.m_awaddr   = rhs_.m_awaddr;
  this.m_awlen    = rhs_.m_awlen;
  this.m_awsize   = rhs_.m_awsize;
  this.m_awburst  = rhs_.m_awburst;
  this.m_awlock   = rhs_.m_awlock;
  this.m_awcache  = rhs_.m_awcache;
  this.m_awprot   = rhs_.m_awprot;
  this.m_awqos    = rhs_.m_awqos;
  this.m_awregion = rhs_.m_awregion;
  this.m_awuser   = rhs_.m_awuser;
  this.m_bid      = rhs_.m_bid;
  this.m_bresp    = rhs_.m_bresp;
  this.m_buser    = rhs_.m_buser;

  // Assigning a queue copies its elements, so the beats below are not shared with rhs.
  this.m_wdata    = rhs_.m_wdata;
  this.m_wstrb    = rhs_.m_wstrb;
  this.m_wuser    = rhs_.m_wuser;
endfunction

function bit axi_mon_write_item::do_compare(uvm_object rhs, uvm_comparer comparer);
  bit beats_match = 1;
  axi_mon_write_item rhs_;

  // These items are only equivalent if rhs is actually an axi_mon_write_item.
  if (rhs == null || !$cast(rhs_, rhs)) begin
    comparer.print_msg("RHS is null or is not an axi_mon_write_item.");
    return 0;
  end

  // uvm_comparer has no support for queues, so the W beats are compared by hand. The monitor
  // appends to all three queues on each beat, so a single length check covers them all.
  if (m_wdata.size() != rhs_.m_wdata.size() ||
      m_wstrb.size() != rhs_.m_wstrb.size() ||
      m_wuser.size() != rhs_.m_wuser.size()) begin
    comparer.print_msg("Different numbers of write data beats.");
    beats_match = 0;
  end else foreach (m_wdata[i]) begin
    beats_match &= comparer.compare_field($sformatf("m_wdata[%0d]", i),
                                          m_wdata[i], rhs_.m_wdata[i], AxiMaxDataWidth, UVM_HEX) &
                   comparer.compare_field($sformatf("m_wstrb[%0d]", i),
                                          m_wstrb[i], rhs_.m_wstrb[i], AxiMaxStrbWidth, UVM_HEX) &
                   comparer.compare_field($sformatf("m_wuser[%0d]", i), m_wuser[i],
                                          rhs_.m_wuser[i], AxiMaxDataUserWidth, UVM_HEX);
  end

  return (super.do_compare(rhs, comparer) &
          comparer.compare_field_int("m_awid", m_awid, rhs_.m_awid, AxiMaxIdWidth, UVM_HEX) &
          comparer.compare_field("m_awaddr", m_awaddr, rhs_.m_awaddr, AxiMaxAddrWidth, UVM_HEX) &
          comparer.compare_field_int("m_awlen", m_awlen, rhs_.m_awlen, AxiLenWidth, UVM_DEC) &
          comparer.compare_field_int("m_awsize", m_awsize, rhs_.m_awsize, AxiSizeWidth, UVM_DEC) &
          comparer.compare_field_int("m_awburst", m_awburst, rhs_.m_awburst, AxiBurstWidth,
                                     UVM_BIN) &
          comparer.compare_field_int("m_awlock", m_awlock, rhs_.m_awlock, 1, UVM_BIN) &
          comparer.compare_field_int("m_awcache", m_awcache, rhs_.m_awcache, AxiCacheWidth,
                                     UVM_BIN) &
          comparer.compare_field_int("m_awprot", m_awprot, rhs_.m_awprot, AxiProtWidth, UVM_BIN) &
          comparer.compare_field_int("m_awqos", m_awqos, rhs_.m_awqos, AxiQosWidth, UVM_HEX) &
          comparer.compare_field_int("m_awregion", m_awregion, rhs_.m_awregion, AxiRegionWidth,
                                     UVM_HEX) &
          comparer.compare_field("m_awuser", m_awuser, rhs_.m_awuser, AxiMaxReqUserWidth,
                                 UVM_HEX) &
          comparer.compare_field_int("m_bid", m_bid, rhs_.m_bid, AxiMaxIdWidth, UVM_HEX) &
          comparer.compare_field_int("m_bresp", m_bresp, rhs_.m_bresp, AxiRespWidth, UVM_HEX) &
          comparer.compare_field_int("m_buser", m_buser, rhs_.m_buser, AxiMaxRespUserWidth,
                                     UVM_HEX) &
          beats_match);
endfunction

function axi_id_t axi_mon_write_item::get_id();
  return m_awid;
endfunction : get_id

function axi_addr_t axi_mon_write_item::get_addr();
  return m_awaddr;
endfunction : get_addr

function axi_dir_e axi_mon_write_item::get_dir();
  return AXI_WRITE;
endfunction : get_dir

function string axi_mon_write_item::convert2string();
  return $sformatf("WRITE id=%0h addr=%0h len=%0d size=%0d burst=%0d beats=%0d m_bresp=%0h",
                   m_awid, m_awaddr, m_awlen, m_awsize, m_awburst, m_wdata.size(), m_bresp);
endfunction : convert2string
