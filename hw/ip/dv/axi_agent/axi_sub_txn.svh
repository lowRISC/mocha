// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Subordinate transaction shared through axi_sub_state: sampled request, write data, response
// policy and driven responses

class axi_sub_txn extends uvm_object;
  `uvm_object_utils(axi_sub_txn)

  bit m_is_write;

  // Acceptance order, counted separately for writes and reads from zero after reset
  int unsigned m_accept_idx;

  // The request as sampled on AW or AR
  axi_txn_request_item m_req;

  // Effective burst matches the request except in AXI4-Lite: one full-width beat (AMBA AXI H.c
  // B1.1.1)
  bit [AxiLenWidth-1:0]  m_len;
  bit [AxiSizeWidth-1:0] m_size;
  burst_e                m_burst;

  // The W beats, in order
  logic [AxiMaxDataWidth-1:0]     m_wdata[$];
  logic [AxiMaxStrbWidth-1:0]     m_wstrb[$];
  logic [AxiMaxDataUserWidth-1:0] m_wuser[$];

  // Response policy and whether it came from a sequence or configuration defaults
  axi_sub_rsp_item m_policy;
  bit              m_policy_from_seq;

  // The response: one BRESP for a write, one RRESP and RDATA per beat for a read
  bit [AxiRespWidth-1:0]    m_bresp;
  bit [AxiRespWidth-1:0]    m_rresp[$];
  bit [AxiMaxDataWidth-1:0] m_rdata[$];

  // Response progress: the cycles left before the response can start, and the R beats sent
  int          m_cycles_to_ready;
  int unsigned m_beats_sent;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern function string convert2string();

  // Class specific methods

  // Return the number of beats in the burst
  extern function int unsigned num_beats();

  // Return a new acceptance record with only the request and policy. Share these items, since they
  // are immutable after acceptance.
  extern function axi_sub_txn get_accept_record();

  // Return zero-based beat n's address and byte lanes on a bus of bus_bytes bytes (see
  // axi_beat_lanes)
  extern function void get_beat(input  int unsigned              n,
                                input  int unsigned              bus_bytes,
                                output bit [AxiMaxAddrWidth-1:0] addr,
                                output int unsigned              lower_lane,
                                output int unsigned              upper_lane);
endclass : axi_sub_txn


function axi_sub_txn::new(string name = "");
  super.new(name);
endfunction : new

function string axi_sub_txn::convert2string();
  return $sformatf("%0s #%0d id=0x%0h addr=0x%0h len=%0d size=%0d burst=%0s",
                   m_is_write ? "write" : "read", m_accept_idx, m_req.m_id, m_req.m_addr, m_len,
                   m_size, m_burst.name());
endfunction : convert2string

function int unsigned axi_sub_txn::num_beats();
  return int'(m_len) + 1;
endfunction : num_beats

function axi_sub_txn axi_sub_txn::get_accept_record();
  axi_sub_txn rec = axi_sub_txn::type_id::create(get_name());

  rec.m_is_write        = m_is_write;
  rec.m_accept_idx      = m_accept_idx;
  rec.m_req             = m_req;
  rec.m_len             = m_len;
  rec.m_size            = m_size;
  rec.m_burst           = m_burst;
  rec.m_policy          = m_policy;
  rec.m_policy_from_seq = m_policy_from_seq;
  return rec;
endfunction : get_accept_record

function void axi_sub_txn::get_beat(input  int unsigned              n,
                                    input  int unsigned              bus_bytes,
                                    output bit [AxiMaxAddrWidth-1:0] addr,
                                    output int unsigned              lower_lane,
                                    output int unsigned              upper_lane);
  axi_beat_lanes(m_req.m_addr, m_size, m_len, m_burst, bus_bytes, n, addr, lower_lane,
                 upper_lane);
endfunction : get_beat
