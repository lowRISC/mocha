// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Send one write beat using m_wdata and m_wstrb as set at start

class axi_single_write_seq extends axi_transfer_seq;
  `uvm_object_utils(axi_single_write_seq)

  // Place the byte at m_addr in the least significant data byte and strobe bit 0. Default strobes
  // cover m_addr through the end of its aligned 1 << m_size container (AMBA AXI H.c A3.4.4).
  rand bit [AxiMaxDataWidth-1:0] m_wdata;
  rand bit [AxiMaxStrbWidth-1:0] m_wstrb;

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  extern virtual protected function void make_wdata(int unsigned bus_bytes,
                                                    int unsigned wuser_width);

  extern constraint single_c;

  extern constraint write_c;

  extern constraint beat_bytes_c;
endclass: axi_single_write_seq


function axi_single_write_seq::new(string name = "");
  super.new(name);
endfunction: new

function void axi_single_write_seq::make_wdata(int unsigned bus_bytes, int unsigned wuser_width);
  m_beat_wdata = '{m_wdata};
  m_beat_wstrb = '{m_wstrb};
  m_beat_wuser = '{'0};
endfunction: make_wdata

constraint axi_single_write_seq::single_c {
  m_req.m_len == 0;
}

constraint axi_single_write_seq::write_c {
  m_write;
}

constraint axi_single_write_seq::beat_bytes_c {
  (m_wdata >> (8 * ((1 << m_req.m_size) - (m_req.m_addr & ((1 << m_req.m_size) - 1))))) == '0;
  (m_wstrb >> ((1 << m_req.m_size) - (m_req.m_addr & ((1 << m_req.m_size) - 1)))) == '0;
  soft m_wstrb == (AxiMaxStrbWidth'(1) <<
                   ((1 << m_req.m_size) - (m_req.m_addr & ((1 << m_req.m_size) - 1)))) - 1;
}
