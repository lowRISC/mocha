// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test both agents in AXI4-Lite mode (+axi_lite=1), exercising every subordinate strobe policy
// (AMBA AXI H.c B1.1.3)

class axi_agent_lite_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_lite_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_lite_vseq


function axi_agent_lite_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_lite_vseq::body();
  axi_lite_strb_policy_e policies[$] = '{AxiLiteStrbUse, AxiLiteStrbIgnore,
                                         AxiLiteStrbErrorPartial};

  if (!cfg.m_is_lite) begin
    `uvm_fatal(get_full_name(), "This sequence needs an AXI4-Lite bus (+axi_lite=1).")
  end
  set_sub_ready(1'b1);
  need("writes_checked", 60);
  need("read_bytes_checked", 100);
  need("slverr_responses", 1);
  need("memory_bytes_compared", 50);
  if ($test$plusargs("axi_x_unstrobed_wdata")) begin
    need("unknown_bytes_written", 1);
  end
  foreach (policies[p]) begin
    // Change the policy at an edge, so the scoreboard checks the last write under the old one
    wait_ready();
    cfg.m_sub_agent_cfg.m_lite_strb_policy = policies[p];
    super.body();
  end
endtask : body
