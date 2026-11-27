// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Randomize READY and response latency. First exercise READY before VALID and delayed READY (AMBA
// AXI H.c A3.2.1), then maximize READY at both ends for back-to-back transfers. Then fix the READY
// delays to test the READY-wait bounds of the assertions at exactly the stalls made, and the READY
// delay of AW and AR at an outstanding limit of one.

class axi_agent_backpressure_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_backpressure_vseq)

  // Stalls per transfer on every channel, and the READY-wait bound, in the bound phase
  int unsigned m_bound_stalls = 3;

  // AW and AR READY delay after VALID in the outstanding-limit phase
  int unsigned m_limit_ready_delay = 6;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Set fixed READY delays that stall every transfer m_bound_stalls edges, bound the wait at that
  // on every interface, and check that each channel's longest stall reached the bound
  extern protected task run_bound_phase();

  // Allow one write and one read in flight, and check that every AW and AR waits its full READY
  // delay after VALID, also when VALID came while the previous transaction was open
  extern protected task run_limit_phase();

  // Hold READY low until delay edges after the first that sees VALID waiting
  extern protected function void set_ready_delay(axi_sub_ready_cfg ready_cfg, int unsigned delay);
endclass : axi_agent_backpressure_vseq


function axi_agent_backpressure_vseq::new(string name = "");
  super.new(name);
  m_run_rsp_seq = 1'b1;
  m_latency_max = 8;
endfunction : new

task axi_agent_backpressure_vseq::body();
  string channels[$] = '{"aw", "w", "b", "ar", "r"};

  cfg.m_sub_agent_cfg.m_max_read_beat_gap = 3;
  foreach (channels[c]) begin
    need({channels[c], "_stalls"}, 10);
    need({channels[c], "_ready_first"}, 10);
    need({channels[c], "_back_to_back"}, 2);
  end

  set_sub_ready(1'b1);
  super.body();

  // Short bursts and long latency queue enough responses for back-to-back B and R handshakes
  set_sub_ready(1'b0);
  m_ready_for_responses = 1'b1;
  m_max_len             = 1;
  foreach (m_rsp_seqs[i]) begin
    m_rsp_seqs[i].m_latency_min = 4;
  end
  super.body();

  run_bound_phase();
  run_limit_phase();
endtask : body

task axi_agent_backpressure_vseq::run_bound_phase();
  string                     channels[5] = '{"AW", "W", "B", "AR", "R"};
  virtual axi_agent_probe_if probe = cfg.m_probe_vif;
  axi_vif_t                  vifs[$];

  // One single-beat transfer at a time, so each B and R accept is waiting before VALID rises. The
  // manager's delay counts the first edge with VALID waiting, and the subordinate's adds to it.
  m_num_workers          = 1;
  m_max_len              = 0;
  m_long_pct             = 0;
  m_response_ready_delay = m_bound_stalls;
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    set_ready_delay(cfg.m_sub_agent_cfgs[s].m_aw_ready, m_bound_stalls - 1);
    set_ready_delay(cfg.m_sub_agent_cfgs[s].m_w_ready, m_bound_stalls - 1);
    set_ready_delay(cfg.m_sub_agent_cfgs[s].m_ar_ready, m_bound_stalls - 1);
  end
  foreach (p_sequencer.m_mgr_agents[m]) begin
    vifs.push_back(p_sequencer.m_mgr_agents[m].get_vif());
  end
  foreach (p_sequencer.m_sub_agents[s]) begin
    vifs.push_back(p_sequencer.m_sub_agents[s].get_vif());
  end
  foreach (vifs[i]) begin
    vifs[i].set_mgr_max_ready_wait(m_bound_stalls);
    vifs[i].set_sub_max_ready_wait(m_bound_stalls);
  end

  wait_ready();
  probe.clear_stall_runs();
  super.body();
  foreach (channels[c]) begin
    if (probe.m_max_stall_run[c] != m_bound_stalls) begin
      `uvm_error(get_full_name(),
                 $sformatf("The longest %0s stall in the bound phase was %0d edges, not %0d.",
                           channels[c], probe.m_max_stall_run[c], m_bound_stalls))
    end
  end

  foreach (vifs[i]) begin
    vifs[i].set_mgr_max_ready_wait(0);
    vifs[i].set_sub_max_ready_wait(0);
  end
endtask : run_bound_phase

task axi_agent_backpressure_vseq::run_limit_phase();
  virtual axi_agent_probe_if probe = cfg.m_probe_vif;
  int unsigned               aw_open_before = probe.m_aw_stalls_while_open;
  int unsigned               ar_open_before = probe.m_ar_stalls_while_open;
  int unsigned               aw_open, ar_open;

  // Parallel workers queue AW and AR requests back-to-back. Quick W data and responses free the
  // place while the next request waits.
  m_num_workers          = 4;
  m_response_ready_delay = 0;
  foreach (m_rsp_seqs[i]) begin
    m_rsp_seqs[i].m_latency_min = 0;
    m_rsp_seqs[i].m_latency_max = 0;
  end
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    axi_sub_agent_cfg sub_cfg = cfg.m_sub_agent_cfgs[s];

    sub_cfg.m_max_outstanding_writes = 1;
    sub_cfg.m_max_outstanding_reads  = 1;
    set_ready_delay(sub_cfg.m_aw_ready, m_limit_ready_delay);
    set_ready_delay(sub_cfg.m_ar_ready, m_limit_ready_delay);
    set_ready_delay(sub_cfg.m_w_ready, 0);
    sub_cfg.m_w_ready.m_ready_before_valid_pct = 100;
  end

  wait_ready();
  probe.clear_stall_runs();
  super.body();
  aw_open = probe.m_aw_stalls_while_open - aw_open_before;
  ar_open = probe.m_ar_stalls_while_open - ar_open_before;
  if (aw_open < 10 || ar_open < 10) begin
    `uvm_error(get_full_name(),
               $sformatf({"AW and AR waited %0d and %0d edges while an earlier write or read was ",
                          "open, so the limit phase did not test READY at the limit."},
                         aw_open, ar_open))
  end
  if (probe.m_min_stall_run[0] < m_limit_ready_delay + 1 ||
      probe.m_min_stall_run[3] < m_limit_ready_delay + 1) begin
    `uvm_error(get_full_name(),
               $sformatf({"With a READY delay of %0d at an outstanding limit of one, an AW ",
                          "handshake followed %0d stalled edges and an AR %0d. Each needs at ",
                          "least %0d."},
                         m_limit_ready_delay, probe.m_min_stall_run[0], probe.m_min_stall_run[3],
                         m_limit_ready_delay + 1))
  end

  foreach (cfg.m_sub_agent_cfgs[s]) begin
    cfg.m_sub_agent_cfgs[s].m_max_outstanding_writes = 0;
    cfg.m_sub_agent_cfgs[s].m_max_outstanding_reads  = 0;
  end
endtask : run_limit_phase

function void axi_agent_backpressure_vseq::set_ready_delay(axi_sub_ready_cfg ready_cfg,
                                                           int unsigned delay);
  ready_cfg.m_ready_before_valid_pct = 0;
  ready_cfg.m_min_valid_to_ready     = delay;
  ready_cfg.m_max_valid_to_ready     = delay;
endfunction : set_ready_delay
