// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Exercise axi_agent_mapped_mem byte-method overrides. The lower half maps to a known initial
// pattern, while the unmapped upper half drops writes and reads as the subordinate default byte.
// The scoreboard predicts both.

class axi_agent_mapped_mem_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_mapped_mem_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_mapped_mem_vseq


function axi_agent_mapped_mem_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_mapped_mem_vseq::body();
  axi_agent_mapped_mem mem = axi_agent_mapped_mem::type_id::create("mapped_mem");

  mem.m_lo = cfg.m_link.m_addr_lo;
  mem.m_hi = cfg.m_link.m_addr_lo + (cfg.m_link.m_addr_hi - cfg.m_link.m_addr_lo + 1) / 2 - 1;
  cfg.m_sub_agent_cfg.m_mem = mem;
  cfg.m_mapped_mem          = 1'b1;
  cfg.m_mapped_lo           = mem.m_lo;
  cfg.m_mapped_hi           = mem.m_hi;

  need("mapped_default_bytes_checked", 100);
  need("unmapped_bytes_checked", 100);
  need("unmapped_bytes_written", 100);
  super.body();
endtask : body
