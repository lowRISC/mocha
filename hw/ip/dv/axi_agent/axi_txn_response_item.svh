// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Manager response: B for a write or one R beat for a read

class axi_txn_response_item extends uvm_sequence_item;
  `uvm_object_utils(axi_txn_response_item)

  // True for the B response to a write, false for an R beat of a read
  bit m_write;

  // BID or RID
  bit [AxiMaxIdWidth-1:0] m_id;

  // R data is shifted so the beat's addressed byte is least significant; bytes outside the beat are
  // zero (AMBA AXI H.c A3.4.4). B responses carry zero.
  bit [AxiMaxDataWidth-1:0] m_rdata;

  // BRESP or RRESP; axi_write_response_item::bresp_e and axi_read_data_item::rresp_e share the
  // OKAY, EXOKAY, SLVERR and DECERR encodings
  bit [AxiRespWidth-1:0] m_resp;

  // RLAST for R beats; set for B, the write's only response
  bit m_last;

  // BUSER or RUSER
  bit [AxiMaxRUserWidth-1:0] m_user;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern function void do_print(uvm_printer printer);
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
  extern function string convert2string();

  // Class specific methods

  // Return whether m_resp is OKAY or EXOKAY
  extern function bit is_okay();
endclass: axi_txn_response_item


function axi_txn_response_item::new(string name = "");
  super.new(name);
endfunction: new

function void axi_txn_response_item::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_field_int("m_write", m_write, 1, UVM_BIN);
  printer.print_field_int("m_id", m_id, AxiMaxIdWidth, UVM_HEX);
  if (!m_write) begin
    printer.print_field("m_rdata", m_rdata, AxiMaxDataWidth, UVM_HEX);
  end
  printer.print_field_int("m_resp", m_resp, AxiRespWidth, UVM_BIN);
  printer.print_field_int("m_last", m_last, 1, UVM_BIN);
  printer.print_field("m_user", m_user, AxiMaxRUserWidth, UVM_HEX);
endfunction: do_print

function void axi_txn_response_item::do_copy(uvm_object rhs);
  axi_txn_response_item rhs_;

  if (rhs == null) begin
    `uvm_fatal("do_copy", "Cannot copy from RHS: it is null.")
  end
  if (!$cast(rhs_, rhs)) begin
    `uvm_fatal("do_copy", "Cannot cast RHS: wrong type?")
  end

  super.do_copy(rhs);
  m_write = rhs_.m_write;
  m_id    = rhs_.m_id;
  m_rdata = rhs_.m_rdata;
  m_resp  = rhs_.m_resp;
  m_last  = rhs_.m_last;
  m_user  = rhs_.m_user;
endfunction: do_copy

function bit axi_txn_response_item::do_compare(uvm_object rhs, uvm_comparer comparer);
  axi_txn_response_item rhs_;

  if (rhs == null || !$cast(rhs_, rhs)) begin
    comparer.print_msg("RHS is null or is not an axi_txn_response_item.");
    return 0;
  end

  return (super.do_compare(rhs, comparer) &
          comparer.compare_field_int("m_write", m_write, rhs_.m_write, 1, UVM_BIN) &
          comparer.compare_field_int("m_id", m_id, rhs_.m_id, AxiMaxIdWidth, UVM_HEX) &
          comparer.compare_field("m_rdata", m_rdata, rhs_.m_rdata, AxiMaxDataWidth, UVM_HEX) &
          comparer.compare_field_int("m_resp", m_resp, rhs_.m_resp, AxiRespWidth, UVM_BIN) &
          comparer.compare_field_int("m_last", m_last, rhs_.m_last, 1, UVM_BIN) &
          comparer.compare_field("m_user", m_user, rhs_.m_user, AxiMaxRUserWidth, UVM_HEX));
endfunction: do_compare

function string axi_txn_response_item::convert2string();
  return $sformatf("%0s id=0x%0h resp=0b%0b last=%0b", m_write ? "B" : "R", m_id, m_resp, m_last);
endfunction: convert2string

function bit axi_txn_response_item::is_okay();
  return m_resp inside {RespOkay, RespExOkay};
endfunction: is_okay
