// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Manager sequence record, compared with the manager monitor's bus observations

class axi_agent_mgr_txn extends uvm_object;
  `uvm_object_utils(axi_agent_mgr_txn)

  // The manager end that sent it, and the transfer
  int unsigned         m_mgr_idx;
  bit                  m_is_write;
  axi_txn_request_item m_req;

  // W beats with the addressed byte least significant (see axi_transfer_seq)
  bit [AxiMaxDataWidth-1:0]     m_wdata[$];
  bit [AxiMaxStrbWidth-1:0]     m_wstrb[$];
  bit [AxiMaxDataUserWidth-1:0] m_wuser[$];

  // B response or R beats, with data aligned like write data
  axi_txn_response_item m_rsps[$];

  // Set if every response arrived, which a reset can prevent
  bit m_complete;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern function string convert2string();

  // Class specific methods

  // Fill this record from a transfer sequence that has finished on manager end mgr_idx
  extern function void set_from_seq(axi_transfer_seq seq, int unsigned mgr_idx = 0);
endclass : axi_agent_mgr_txn


function axi_agent_mgr_txn::new(string name = "");
  super.new(name);
endfunction : new

function string axi_agent_mgr_txn::convert2string();
  return $sformatf("%0s id=0x%0h addr=0x%0h len=%0d size=%0d burst=%0s lock=%0b",
                   m_is_write ? "write" : "read", m_req.m_id, m_req.m_addr, m_req.m_len,
                   m_req.m_size, m_req.m_burst.name(), m_req.m_lock);
endfunction : convert2string

function void axi_agent_mgr_txn::set_from_seq(axi_transfer_seq seq, int unsigned mgr_idx = 0);
  m_mgr_idx  = mgr_idx;
  m_is_write = seq.m_write;
  m_req      = seq.m_requests[0];
  m_wdata    = seq.m_beat_wdata;
  m_wstrb    = seq.m_beat_wstrb;
  m_wuser    = seq.m_beat_wuser;
  m_rsps     = seq.m_responses;
  m_complete = seq.has_full_transaction();
endfunction : set_from_seq
