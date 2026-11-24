// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Keep many transactions outstanding, reorder responses and interleave read data across IDs (AMBA
// AXI H.c A5.1, E1.12). Reuse outstanding IDs often to check same-ID ordering.

class axi_agent_out_of_order_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_out_of_order_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_out_of_order_vseq


function axi_agent_out_of_order_vseq::new(string name = "");
  super.new(name);
  m_num_workers = 8;
  m_run_rsp_seq = 1'b1;
  m_latency_max = 16;
endfunction : new

task axi_agent_out_of_order_vseq::body();
  cfg.m_sub_agent_cfg.m_out_of_order    = 1'b1;
  cfg.m_sub_agent_cfg.m_read_interleave = 1'b1;
  need("write_reorders", 5);
  need("read_reorders", 5);
  need("interleaved_r_beats", 5);
  need("same_id_requests", 5);
  need("mgr_writes_matched", 20);
  need("mgr_reads_matched", 20);
  super.body();

  // Long interleaved reads can hold most workers, leaving the writes too sparse to overlap
  m_write_pct = 100;
  m_long_pct  = 0;
  num_trans   = 20;
  run_workers();
endtask : body
