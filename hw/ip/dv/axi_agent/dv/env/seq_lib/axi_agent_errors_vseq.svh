// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Inject DECERR from a 4KB error page and SLVERR or DECERR from response policies. The scoreboard
// predicts responses from both sources and checks that failed writes leave memory unchanged.

class axi_agent_errors_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_errors_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_errors_vseq


function axi_agent_errors_vseq::new(string name = "");
  super.new(name);
  m_run_rsp_seq = 1'b1;
  m_latency_max = 4;
  m_error_pct   = 15;
endfunction : new

task axi_agent_errors_vseq::body();
  cfg.m_sub_agent_cfg.m_err_addr_valid = 1'b1;
  cfg.m_sub_agent_cfg.m_err_addr       = AgentErrPage;
  cfg.m_sub_agent_cfg.m_err_addr_mask  = 64'hfff;
  cfg.m_sub_agent_cfg.m_err_resp       = RespDecerr;
  need("slverr_responses", 5);
  need("decerr_responses", 5);
  need("memory_bytes_compared", 100);
  super.body();
endtask : body
