// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A subclass of axi_mgr_write_data_seq that sends a caller-supplied list of write data items, one
// per beat, in order. Used for multi-beat write bursts. The beats are not randomised: each item is
// driven verbatim as supplied, except WLAST.
//
// Usage: populate m_items with the beats to send, in order, before starting the sequence. The
// listed_items_c constraint ties the beat count to m_items.size(), so the list must be in place
// before randomize()/start(); each entry is then driven as one beat.
class axi_mgr_write_listed_data_seq extends axi_mgr_write_data_seq;
  `uvm_object_utils(axi_mgr_write_listed_data_seq)

  // The data beats to send, in order. One item is sent per beat. Beats are not randomized.
  axi_write_data_item m_items[$];

  // Index of the next beat to send.
  local int unsigned m_idx;

  extern function new(string name="");

  // Overrides axi_mgr_write_data_seq::populate_item to "produce" each beat by copying the next
  // caller-supplied item rather than randomising it.
  extern protected virtual function void populate_item(axi_write_data_item item, bit is_last);

  // Send exactly one beat per item in m_items.
  extern constraint listed_items_c;
endclass

function axi_mgr_write_listed_data_seq::new(string name="");
  super.new(name);
  m_idx = 0;
endfunction

function void axi_mgr_write_listed_data_seq::populate_item(axi_write_data_item item, bit is_last);
  // This replaces the base class function. Items are copied from m_items.  The base body() 
  // drives m_last via is_last, so honour that here. The last beat in the burst must assert 
  // WLAST regardless of what the caller stored in the item.
  item.copy(m_items[m_idx]);
  item.m_last = is_last;
  m_idx++;
endfunction

constraint axi_mgr_write_listed_data_seq::listed_items_c {
  m_number_of_items == m_items.size();
}
