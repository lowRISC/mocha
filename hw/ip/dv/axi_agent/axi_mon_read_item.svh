// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitored AXI read transaction: the read address (AR) and the read data beats (R).
// Published on tx_ap once complete.

class axi_mon_read_item extends axi_mon_item;
  `uvm_object_utils(axi_mon_read_item)

  // All varaibles are 4-state so X values can reach any potential checkers
  // Read address (AR)
  axi_id_t                       m_arid;
  axi_addr_t                     m_araddr;
  logic [AxiLenWidth-1:0]        m_arlen;
  logic [AxiSizeWidth-1:0]       m_arsize;
  logic [AxiBurstWidth-1:0]      m_arburst;
  logic                          m_arlock;
  logic [AxiCacheWidth-1:0]      m_arcache;
  logic [AxiProtWidth-1:0]       m_arprot;
  logic [AxiQosWidth-1:0]        m_arqos;
  logic [AxiRegionWidth-1:0]     m_arregion;
  logic [AxiMaxReqUserWidth-1:0] m_aruser;

  // Read data (R) — one entry per beat. RLAST is not stored: the monitor ends the burst on it,
  // so the beat count is m_rdata.size().
  axi_id_t                       m_rid;
  logic [AxiMaxDataWidth-1:0]    m_rdata[$];
  logic [AxiRespWidth-1:0]       m_rresp[$];
  logic [AxiMaxRUserWidth-1:0]   m_ruser[$];

  extern function new(string name = "");
  extern function void do_print(uvm_printer printer);
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);

  extern virtual function axi_id_t   get_id();
  extern virtual function axi_addr_t get_addr();
  extern virtual function axi_dir_e  get_dir();
  extern virtual function string     convert2string();

endclass : axi_mon_read_item

function axi_mon_read_item::new(string name = "");
  super.new(name);
endfunction : new

function void axi_mon_read_item::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_field_int("m_arid", m_arid, AxiMaxIdWidth, UVM_HEX);
  printer.print_field("m_araddr", m_araddr, AxiMaxAddrWidth, UVM_HEX);
  printer.print_field_int("m_arlen", m_arlen, AxiLenWidth, UVM_DEC);
  printer.print_field_int("m_arsize", m_arsize, AxiSizeWidth, UVM_DEC);
  printer.print_field_int("m_arburst", m_arburst, AxiBurstWidth, UVM_BIN);
  printer.print_field_int("m_arlock", m_arlock, 1, UVM_BIN);
  printer.print_field_int("m_arcache", m_arcache, AxiCacheWidth, UVM_BIN);
  printer.print_field_int("m_arprot", m_arprot, AxiProtWidth, UVM_BIN);
  printer.print_field_int("m_arqos", m_arqos, AxiQosWidth, UVM_HEX);
  printer.print_field_int("m_arregion", m_arregion, AxiRegionWidth, UVM_HEX);
  printer.print_field("m_aruser", m_aruser, AxiMaxReqUserWidth, UVM_HEX);
  printer.print_field_int("m_rid", m_rid, AxiMaxIdWidth, UVM_HEX);
  foreach (m_rdata[i]) begin
    printer.print_field($sformatf("m_rdata[%0d]", i), m_rdata[i], AxiMaxDataWidth, UVM_HEX);
  end
  foreach (m_rresp[i]) begin
    printer.print_field_int($sformatf("m_rresp[%0d]", i), m_rresp[i], AxiRespWidth, UVM_HEX);
  end
  foreach (m_ruser[i]) begin
    printer.print_field($sformatf("m_ruser[%0d]", i), m_ruser[i], AxiMaxRUserWidth, UVM_HEX);
  end
endfunction

function void axi_mon_read_item::do_copy(uvm_object rhs);
  axi_mon_read_item rhs_;

  if (rhs == null) `uvm_fatal("do_copy", "Cannot copy from RHS: it is null.")
  if (!$cast(rhs_, rhs)) `uvm_fatal("do_copy", "Cannot cast RHS: wrong type?")

  super.do_copy(rhs);
  this.m_arid     = rhs_.m_arid;
  this.m_araddr   = rhs_.m_araddr;
  this.m_arlen    = rhs_.m_arlen;
  this.m_arsize   = rhs_.m_arsize;
  this.m_arburst  = rhs_.m_arburst;
  this.m_arlock   = rhs_.m_arlock;
  this.m_arcache  = rhs_.m_arcache;
  this.m_arprot   = rhs_.m_arprot;
  this.m_arqos    = rhs_.m_arqos;
  this.m_arregion = rhs_.m_arregion;
  this.m_aruser   = rhs_.m_aruser;
  this.m_rid      = rhs_.m_rid;

  // Assigning a queue copies its elements, so the beats below are not shared with rhs.
  this.m_rdata    = rhs_.m_rdata;
  this.m_rresp    = rhs_.m_rresp;
  this.m_ruser    = rhs_.m_ruser;
endfunction

function bit axi_mon_read_item::do_compare(uvm_object rhs, uvm_comparer comparer);
  bit beats_match = 1;
  axi_mon_read_item rhs_;

  // These items are only equivalent if rhs is actually an axi_mon_read_item.
  if (rhs == null || !$cast(rhs_, rhs)) begin
    comparer.print_msg("RHS is null or is not an axi_mon_read_item.");
    return 0;
  end

  // uvm_comparer has no support for queues, so the R beats are compared by hand. The monitor
  // appends to all three queues on each beat, so a single length check covers them all.
  if (m_rdata.size() != rhs_.m_rdata.size() ||
      m_rresp.size() != rhs_.m_rresp.size() ||
      m_ruser.size() != rhs_.m_ruser.size()) begin
    comparer.print_msg("Different numbers of read data beats.");
    beats_match = 0;
  end else foreach (m_rdata[i]) begin
    beats_match &= comparer.compare_field($sformatf("m_rdata[%0d]", i),
                                          m_rdata[i], rhs_.m_rdata[i], AxiMaxDataWidth, UVM_HEX) &
                   comparer.compare_field_int($sformatf("m_rresp[%0d]", i),
                                              m_rresp[i], rhs_.m_rresp[i], AxiRespWidth, UVM_HEX) &
                   comparer.compare_field($sformatf("m_ruser[%0d]", i),
                                          m_ruser[i], rhs_.m_ruser[i], AxiMaxRUserWidth, UVM_HEX);
  end

  return (super.do_compare(rhs, comparer) &
          comparer.compare_field_int("m_arid", m_arid, rhs_.m_arid, AxiMaxIdWidth, UVM_HEX) &
          comparer.compare_field("m_araddr", m_araddr, rhs_.m_araddr, AxiMaxAddrWidth, UVM_HEX) &
          comparer.compare_field_int("m_arlen", m_arlen, rhs_.m_arlen, AxiLenWidth, UVM_DEC) &
          comparer.compare_field_int("m_arsize", m_arsize, rhs_.m_arsize, AxiSizeWidth, UVM_DEC) &
          comparer.compare_field_int("m_arburst", m_arburst, rhs_.m_arburst, AxiBurstWidth,
                                     UVM_BIN) &
          comparer.compare_field_int("m_arlock", m_arlock, rhs_.m_arlock, 1, UVM_BIN) &
          comparer.compare_field_int("m_arcache", m_arcache, rhs_.m_arcache, AxiCacheWidth,
                                     UVM_BIN) &
          comparer.compare_field_int("m_arprot", m_arprot, rhs_.m_arprot, AxiProtWidth, UVM_BIN) &
          comparer.compare_field_int("m_arqos", m_arqos, rhs_.m_arqos, AxiQosWidth, UVM_HEX) &
          comparer.compare_field_int("m_arregion", m_arregion, rhs_.m_arregion, AxiRegionWidth,
                                     UVM_HEX) &
          comparer.compare_field("m_aruser", m_aruser, rhs_.m_aruser, AxiMaxReqUserWidth,
                                 UVM_HEX) &
          comparer.compare_field_int("m_rid", m_rid, rhs_.m_rid, AxiMaxIdWidth, UVM_HEX) &
          beats_match);
endfunction

function axi_id_t axi_mon_read_item::get_id();
  return m_arid;
endfunction : get_id

function axi_addr_t axi_mon_read_item::get_addr();
  return m_araddr;
endfunction : get_addr

function axi_dir_e axi_mon_read_item::get_dir();
  return AXI_READ;
endfunction : get_dir

function string axi_mon_read_item::convert2string();
  return $sformatf("READ id=%0h addr=%0h len=%0d size=%0d burst=%0d beats=%0d",
                   m_arid, m_araddr, m_arlen, m_arsize, m_arburst, m_rdata.size());
endfunction : convert2string
