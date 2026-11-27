// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test two managers and three subordinates through axi_xbar with the transaction limits of mocha's
// crossbar.
// Random traffic reaches every subordinate with manager-index ID widening, reordered responses,
// interleaved reads and policy errors. The unmapped top 4KB returns DECERR. The scoreboard checks
// both ends.

class axi_agent_xbar_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_xbar_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_xbar_vseq


function axi_agent_xbar_vseq::new(string name = "");
  super.new(name);
  m_run_rsp_seq = 1'b1;
  m_latency_max = 6;
  m_error_pct   = 5;
  m_num_workers = 6;
endfunction : new

task axi_agent_xbar_vseq::body();
  num_trans = 50;
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    cfg.m_sub_agent_cfgs[s].m_out_of_order    = 1'b1;
    cfg.m_sub_agent_cfgs[s].m_read_interleave = 1'b1;
    need($sformatf("sub%0d_requests", s), 20);
  end
  set_sub_ready(1'b1);
  need("widened_ids", 20);
  need("concurrent_subordinates", 20);
  need("decode_errors", 2);
  need("link_writes_matched", 50);
  need("link_reads_matched", 50);
  need("read_bytes_checked", 200);
  need("memory_bytes_compared", 200);
  super.body();
endtask : body
