// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A sequence item that represents a response to an AXI read
//
// The fields are null/empty when the instance is created, and should be filled with results of the
// two sequences (which may be null if the sequences were interrupted by a reset).

class axi_fixed_read_rsp_item extends uvm_sequence_item;
  `uvm_object_utils(axi_fixed_read_rsp_item)
  // The status of the read request transfer (which either completed or was interrupted by reset)
  axi_status_item    m_ar_status;

  // The R channel read data beats. Empty if a reset interrupted the read before any beat arrived.
  axi_read_data_item m_read_data[$];

  extern function new(string name = "");
  extern function void do_print(uvm_printer printer);
  extern function void do_copy(uvm_object rhs);
  extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
endclass

function axi_fixed_read_rsp_item::new(string name = "");
  super.new(name);
endfunction

function void axi_fixed_read_rsp_item::do_print(uvm_printer printer);
  super.do_print(printer);
  printer.print_object("m_ar_status", m_ar_status);
  foreach (m_read_data[i]) printer.print_object($sformatf("m_read_data[%0d]", i), m_read_data[i]);
endfunction

function void axi_fixed_read_rsp_item::do_copy(uvm_object rhs);
  axi_fixed_read_rsp_item rhs_;

  if (rhs == null) `uvm_fatal("do_copy", "Cannot copy from RHS: it is null.")
  if (!$cast(rhs_, rhs)) `uvm_fatal("do_copy", "Cannot cast RHS: wrong type?")

  super.do_copy(rhs);
  if (rhs_.m_ar_status == null) m_ar_status = null;
  else if (!$cast(m_ar_status, rhs_.m_ar_status.clone())) begin
    `uvm_fatal("do_copy", "Failed to clone m_ar_status.")
  end

  m_read_data.delete();
  foreach (rhs_.m_read_data[i]) begin
    axi_read_data_item beat;
    if (!$cast(beat, rhs_.m_read_data[i].clone())) begin
      `uvm_fatal("do_copy", "Failed to clone m_read_data beat.")
    end
    m_read_data.push_back(beat);
  end
endfunction

function bit axi_fixed_read_rsp_item::do_compare(uvm_object rhs, uvm_comparer comparer);
  bit beats_match = 1;
  axi_fixed_read_rsp_item rhs_;

  // These items are only equivalent if rhs is actually an axi_fixed_read_rsp_item.
  if (rhs == null || !$cast(rhs_, rhs)) begin
    comparer.print_msg("RHS is null or is not an axi_fixed_read_rsp_item.");
    return 0;
  end

  if (m_read_data.size() != rhs_.m_read_data.size()) beats_match = 0;
  else foreach (m_read_data[i]) begin
    beats_match &= comparer.compare_object($sformatf("m_read_data[%0d]", i),
                                           m_read_data[i], rhs_.m_read_data[i]);
  end

  return (super.do_compare(rhs, comparer) &
          comparer.compare_object("m_ar_status", m_ar_status, rhs_.m_ar_status) &
          beats_match);
endfunction
