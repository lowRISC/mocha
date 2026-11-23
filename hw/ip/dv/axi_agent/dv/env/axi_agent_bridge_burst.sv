// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Manager burst on lite_bridge, retained until it completes and every beat has a completed
// subordinate AXI4-Lite transfer, or a write beat with no strobes has none (AMBA AXI H.c B1.1.3)

class axi_agent_bridge_burst extends uvm_object;
  `uvm_object_utils(axi_agent_bridge_burst)

  typedef bit [AxiMaxAddrWidth-1:0] addr_t;

  // The request, and once it completes at the manager end, the transaction and when it completed
  axi_mon_item m_req;
  axi_mon_item m_txn;
  realtime     m_txn_time;

  // Per beat: address, an AXI4-Lite transfer to that address and its subordinate completion index.
  // Beats with one address take its transfers in completion order.
  addr_t       m_beat_addrs[$];
  axi_mon_item m_transfers[$];
  int unsigned m_transfer_nums[$];

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  // Return whether every beat has its AXI4-Lite transfer
  extern function bit has_all_transfers();

  // Return whether beat n of the completed transaction is a write beat with no strobes on a bus of
  // bus_bytes bytes
  extern function bit is_zero_strobe(int unsigned n, int unsigned bus_bytes);

  // Return whether each address has at least as many transfers as beats with strobes
  extern function bit has_strobed_transfers(int unsigned bus_bytes);

  // Give each beat its transfer and completion index, or null for a beat with no strobes that the
  // bridge suppressed, keeping completion order per address. Return transfers that no beat takes.
  extern function void map_transfers(input  int unsigned bus_bytes,
                                     output axi_mon_item xfers[$],
                                     output int unsigned nums[$],
                                     output axi_mon_item extra[$]);

  // Return whether an AXI4-Lite transfer is a write with no strobes
  extern local function bit is_zero_strobe_xfer(axi_mon_item xfer, int unsigned bus_bytes);
endclass : axi_agent_bridge_burst


function axi_agent_bridge_burst::new(string name = "");
  super.new(name);
endfunction : new

function bit axi_agent_bridge_burst::has_all_transfers();
  foreach (m_transfers[n]) begin
    if (m_transfers[n] == null) begin
      return 1'b0;
    end
  end
  return 1'b1;
endfunction : has_all_transfers

function bit axi_agent_bridge_burst::is_zero_strobe(int unsigned n, int unsigned bus_bytes);
  axi_mon_write_item item;

  if (m_txn == null || !$cast(item, m_txn) || n >= item.m_wstrb.size()) begin
    return 1'b0;
  end
  return (item.m_wstrb[n] & ((AxiMaxStrbWidth'(1) << bus_bytes) - 1)) === '0;
endfunction : is_zero_strobe

function bit axi_agent_bridge_burst::is_zero_strobe_xfer(axi_mon_item xfer, int unsigned bus_bytes);
  axi_mon_write_item item;

  if (xfer == null || !$cast(item, xfer) || item.m_wstrb.size() == 0) begin
    return 1'b0;
  end
  return (item.m_wstrb[0] & ((AxiMaxStrbWidth'(1) << bus_bytes) - 1)) === '0;
endfunction : is_zero_strobe_xfer

function bit axi_agent_bridge_burst::has_strobed_transfers(int unsigned bus_bytes);
  // Beats with strobes minus transfers, per address
  int need[addr_t];

  foreach (m_beat_addrs[n]) begin
    if (!need.exists(m_beat_addrs[n])) begin
      need[m_beat_addrs[n]] = 0;
    end
    if (!is_zero_strobe(n, bus_bytes)) begin
      need[m_beat_addrs[n]]++;
    end
    if (m_transfers[n] != null) begin
      need[m_beat_addrs[n]]--;
    end
  end
  foreach (need[addr]) begin
    if (need[addr] > 0) begin
      return 1'b0;
    end
  end
  return 1'b1;
endfunction : has_strobed_transfers

function void axi_agent_bridge_burst::map_transfers(input  int unsigned bus_bytes,
                                                    output axi_mon_item xfers[$],
                                                    output int unsigned nums[$],
                                                    output axi_mon_item extra[$]);
  axi_mon_item avail[addr_t][$];
  int unsigned avail_nums[addr_t][$];
  int unsigned beats[addr_t];

  xfers.delete();
  nums.delete();
  extra.delete();
  foreach (m_beat_addrs[n]) begin
    if (!beats.exists(m_beat_addrs[n])) begin
      beats[m_beat_addrs[n]] = 0;
    end
    beats[m_beat_addrs[n]]++;
    if (m_transfers[n] != null) begin
      avail[m_beat_addrs[n]].push_back(m_transfers[n]);
      avail_nums[m_beat_addrs[n]].push_back(m_transfer_nums[n]);
    end
  end

  // While an address has fewer transfers left than beats, a beat with no strobes takes the next
  // transfer only if that has no strobes either
  foreach (m_beat_addrs[n]) begin
    addr_t addr = m_beat_addrs[n];
    bit    take = 1'b0;

    if (avail.exists(addr) && avail[addr].size() > 0) begin
      take = avail[addr].size() >= beats[addr] || !is_zero_strobe(n, bus_bytes) ||
             is_zero_strobe_xfer(avail[addr][0], bus_bytes);
    end
    if (take) begin
      xfers.push_back(avail[addr].pop_front());
      nums.push_back(avail_nums[addr].pop_front());
    end else begin
      xfers.push_back(null);
      nums.push_back(0);
    end
    beats[addr]--;
  end
  foreach (avail[addr]) begin
    foreach (avail[addr][i]) begin
      extra.push_back(avail[addr][i]);
    end
  end
endfunction : map_transfers
