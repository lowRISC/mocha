// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check against independent pulp_axi models to catch shared protocol mistakes in the agents. Each
// test has its own link (see axi_agent_link_cfg).

// axi_rand_master on pulp_mgr exercises reordering, read interleaving, random stalls and errors.
// During mixed traffic, overlapping reads and writes prevent read-data prediction, so check
// responses only. Then run reads alone in the same window and check data from completed writes.
class axi_agent_pulp_mgr_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_mgr_vseq)

  int unsigned m_num_reads  = 300;
  int unsigned m_num_writes = 300;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Run the random manager for n_reads reads and n_writes writes, and wait for it to finish
  extern protected task run_pulp_mgr(int unsigned n_reads, int unsigned n_writes);
endclass : axi_agent_pulp_mgr_vseq


function axi_agent_pulp_mgr_vseq::new(string name = "");
  super.new(name);
  m_latency_max = 8;
  m_error_pct   = 10;
endfunction : new

task axi_agent_pulp_mgr_vseq::run_pulp_mgr(int unsigned n_reads, int unsigned n_writes);
  int unsigned runs_done = cfg.m_pulp_ctrl_vif.runs_done;

  cfg.m_pulp_ctrl_vif.n_reads  = n_reads;
  cfg.m_pulp_ctrl_vif.n_writes = n_writes;
  cfg.m_pulp_ctrl_vif.start    = 1'b1;
  wait (cfg.m_pulp_ctrl_vif.runs_done == runs_done + 1);
endtask : run_pulp_mgr

task axi_agent_pulp_mgr_vseq::body();
  string kind = "mixed";

  cfg.m_sub_agent_cfg.m_out_of_order    = 1'b1;
  cfg.m_sub_agent_cfg.m_read_interleave = 1'b1;
  set_sub_ready(1'b1);
  need("writes_checked", m_num_writes);
  need("reads_checked", 2 * m_num_reads);
  need("read_reorders", 5);
  need("interleaved_r_beats", 5);
  need("slverr_responses", 5);
  need("memory_bytes_compared", 500);
  need("read_bytes_checked", 2000);

  // The INCR-only manager sends bursts of up to 256 beats (see tb.sv)
  void'($value$plusargs("pulp_mgr_kind=%s", kind));
  if (kind == "incr") begin
    need("long_writes", 20);
    need("long_reads", 20);
  end

  run_rsp_seq_nonblocking();
  wait_ready();
  cfg.m_link.m_predict_reads = 1'b0;
  run_pulp_mgr(m_num_reads, m_num_writes);
  cfg.m_link.m_predict_reads = 1'b1;
  run_pulp_mgr(m_num_reads, 0);
endtask : body


// AXI4-Lite driver on pulp_lite_mgr sends serial accesses in a small window so reads often check
// written bytes
class axi_agent_pulp_lite_mgr_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_lite_mgr_vseq)

  int unsigned m_num_ops = 300;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_lite_mgr_vseq


function axi_agent_pulp_lite_mgr_vseq::new(string name = "");
  super.new(name);
  m_latency_max = 4;
endfunction : new

task axi_agent_pulp_lite_mgr_vseq::body();
  set_sub_ready(1'b1);
  need("writes_checked", m_num_ops / 4);
  need("reads_checked", m_num_ops / 4);
  need("read_bytes_checked", m_num_ops / 4);

  run_rsp_seq_nonblocking();
  wait_ready();
  for (int unsigned i = 0; i < m_num_ops; i++) begin
    bit [31:0] addr = cfg.m_link.m_addr_lo + $urandom_range(0, 255);
    bit [7:0]  strb = '0;

    // Strobes only on the lanes from the address up (H.c A3.4.4)
    for (int unsigned lane = addr % 4; lane < 4; lane++) begin
      strb[lane] = $urandom_range(0, 1);
    end
    cfg.m_pulp_ctrl_vif.push_op($urandom_range(0, 1), addr, {$urandom(), $urandom()}, strb);
  end
  wait (cfg.m_pulp_ctrl_vif.ops_done == m_num_ops);
endtask : body


// axi_sim_mem on sim_mem has 4KB SLVERR and DECERR pages. Align FIXED bursts because
// axi_pkg::beat_upper_byte extends later unaligned FIXED beats past their container.
class axi_agent_sim_mem_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_sim_mem_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_sim_mem_vseq


function axi_agent_sim_mem_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_sim_mem_vseq::body();
  num_trans = 100;
  need("slverr_responses", 2);
  need("decerr_responses", 2);
  need("read_bytes_checked", 100);
  need("mgr_reads_matched", 40);
  super.body();
endtask : body


// axi_rand_slave on rand_slave reorders and interleaves reads across IDs. In MAPPED mode without
// RAND_RESP or exclusive requests, all responses are OKAY.
class axi_agent_rand_slave_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_rand_slave_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_rand_slave_vseq


function axi_agent_rand_slave_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_rand_slave_vseq::body();
  num_trans = 100;
  need("read_bytes_checked", 100);
  need("interleaved_r_beats", 2);
  need("mgr_reads_matched", 40);
  super.body();
endtask : body


// Test the AXI4-Lite manager against the 64-bit axi_lite_regs block on lite_regs
class axi_agent_lite_regs_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_lite_regs_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_lite_regs_vseq


function axi_agent_lite_regs_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_lite_regs_vseq::body();
  num_trans = 60;
  need("writes_checked", 60);
  need("read_bytes_checked", 100);
  super.body();
endtask : body


// A response policy item whose injected error is always SLVERR
class axi_agent_slverr_rsp_item extends axi_sub_rsp_item;
  `uvm_object_utils(axi_agent_slverr_rsp_item)

  // Standard SV/UVM methods
  extern function new(string name = "");

  extern constraint slverr_c;
endclass : axi_agent_slverr_rsp_item


function axi_agent_slverr_rsp_item::new(string name = "");
  super.new(name);
endfunction : new

constraint axi_agent_slverr_rsp_item::slverr_c {
  m_error_resp == RespSlverr;
}


// Test axi_to_axi_lite on lite_bridge with an AXI4 manager and AXI4-Lite subordinate, as in mocha.
// Combine write responses, keeping the first SLVERR or DECERR (AMBA AXI H.c B1.3.1). Use directed
// responses, then write bursts with beats that have no strobes, then random traffic. Inject only
// SLVERR unless m_link.m_bridge_decerr is set. The bridge answers SLVERR to a multi-beat burst
// whose first error is DECERR.
class axi_agent_lite_bridge_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_lite_bridge_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Send a full-width INCR burst with one beat per resps entry. Answer beat n's AXI4-Lite transfer
  // with resps[n] and check the burst response.
  extern protected task directed_burst(bit is_write, axi_resp_e resps[$]);

  // Send a full-width write burst with one beat per strbs entry and check that it gets OKAY. A
  // bridge may suppress the beats whose entry is zero (H.c B1.1.3).
  extern protected task zero_strobe_burst(burst_e burst_type, bit [AxiMaxStrbWidth-1:0] strbs[$]);
endclass : axi_agent_lite_bridge_vseq


function axi_agent_lite_bridge_vseq::new(string name = "");
  super.new(name);
  m_latency_max = 4;
  m_error_pct   = 20;
endfunction : new

task axi_agent_lite_bridge_vseq::directed_burst(bit is_write, axi_resp_e resps[$]);
  axi_agent_preset_rsp_seq rsp_seq = axi_agent_preset_rsp_seq::type_id::create("rsp_seq");
  axi_agent_rand_req       req = new_req();
  axi_transfer_seq         seq;
  axi_resp_e               exp_bresp = RespOkay;
  int unsigned             partial_strb_pct = m_partial_strb_pct;

  // AXI4-Lite transfers take policies and respond in acceptance order
  foreach (resps[n]) begin
    rsp_seq.add_item(resps[n], 0);
    if (exp_bresp == RespOkay) begin
      exp_bresp = resps[n];
    end
  end
  cfg.m_rsp_seqs[0].push_back(rsp_seq);
  fork
    rsp_seq.start(p_sequencer.m_sub_sequencer);
  join_none

  // 128-byte alignment keeps up to 16 eight-byte beats within a 4KB page
  req.m_addr  = (req.m_addr >> 7) << 7;
  req.m_len   = resps.size() - 1;
  req.m_size  = $clog2(cfg.m_data_width / 8);
  req.m_burst = BurstIncr;
  req.m_lock  = 1'b0;
  wait_ready();

  // Full strobes, so that every write beat reaches the subordinate and takes its policy
  m_partial_strb_pct = 0;
  send(req, is_write, seq);
  m_partial_strb_pct = partial_strb_pct;

  if (rsp_seq.m_sent != resps.size()) begin
    `uvm_error(get_full_name(), $sformatf("The burst at 0x%0h took %0d of its %0d policy items.",
                                          req.m_addr, rsp_seq.m_sent, resps.size()))
  end
  if (is_write) begin
    if (seq.m_responses.size() != 1 || seq.m_responses[0].m_resp != exp_bresp) begin
      `uvm_error(get_full_name(),
                 $sformatf({"The write burst at 0x%0h, whose AXI4-Lite writes were answered %p, ",
                            "did not get %0s."},
                           req.m_addr, resps, exp_bresp.name()))
    end
  end else begin
    foreach (resps[n]) begin
      if (n >= seq.m_responses.size() || seq.m_responses[n].m_resp != resps[n]) begin
        `uvm_error(get_full_name(), $sformatf("Beat %0d of the read burst at 0x%0h was not %0s.",
                                              n, req.m_addr, resps[n].name()))
      end
    end
  end
endtask : directed_burst

task axi_agent_lite_bridge_vseq::zero_strobe_burst(burst_e burst_type,
                                                   bit [AxiMaxStrbWidth-1:0] strbs[$]);
  axi_agent_rand_req        req = new_req();
  axi_transfer_seq          seq = axi_transfer_seq::type_id::create("seq");
  bit [AxiMaxAddrWidth-1:0] addr = (req.m_addr >> 7) << 7;
  int unsigned              len = strbs.size() - 1;
  int unsigned              size = $clog2(cfg.m_data_width / 8);

  seq.set_bus_properties(p_sequencer.m_mgr_agents[0].get_vif());
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_write  == 1'b1;
                                 m_req.m_id     == local::req.m_id;
                                 m_req.m_addr   == local::addr;
                                 m_req.m_len    == local::len;
                                 m_req.m_size   == local::size;
                                 m_req.m_burst  == local::burst_type;
                                 m_req.m_lock   == 1'b0;
                                 m_req.m_cache  == local::req.m_cache;
                                 m_req.m_prot   == local::req.m_prot;
                                 m_req.m_qos    == local::req.m_qos;
                                 m_req.m_region == local::req.m_region;
                                 m_req.m_user   == local::req.m_user;)
  foreach (strbs[n]) begin
    bit [AxiMaxDataWidth-1:0] data;

    for (int unsigned i = 0; i < AxiMaxDataWidth; i += 32) begin
      data[i +: 32] = $urandom();
    end
    seq.m_beat_wdata.push_back(data & ((AxiMaxDataWidth'(1) << cfg.m_data_width) - 1));
    seq.m_beat_wstrb.push_back(strbs[n]);
    seq.m_beat_wuser.push_back('0);
  end
  wait_ready();
  seq.start(p_sequencer.m_mgr_sequencers[0]);
  record(seq, 0);

  if (seq.m_responses.size() != 1 || seq.m_responses[0].m_resp != RespOkay) begin
    `uvm_error(get_full_name(),
               $sformatf("The %0s write burst at 0x%0h with strobes %p did not get OKAY.",
                         burst_type.name(), addr, strbs))
  end
endtask : zero_strobe_burst

task axi_agent_lite_bridge_vseq::body();
  bit [AxiMaxStrbWidth-1:0] full = (AxiMaxStrbWidth'(1) << (cfg.m_data_width / 8)) - 1;
  bit [AxiMaxStrbWidth-1:0] strbs[$];
  axi_resp_e                resps[$];

  num_trans = 60;
  set_sub_ready(1'b1);
  need("read_bytes_checked", 200);
  need("memory_bytes_compared", 200);
  need("bridge_writes_matched", 50);
  need("bridge_reads_matched", 50);
  need("bridge_error_bursts", 5);
  need("bridge_zero_strobe_beats", 6);
  need("slverr_responses", 5);
  if (cfg.m_link.m_bridge_decerr) begin
    need("bridge_mixed_error_bursts", 2);
    need("bridge_decerr_bursts", 3);
  end else begin
    axi_sub_rsp_item::type_id::set_type_override(axi_agent_slverr_rsp_item::get_type());
  end

  // Exercise write errors at each burst position and multiple read-beat errors
  resps = {RespOkay, RespSlverr, RespOkay, RespOkay};
  directed_burst(1'b1, resps);
  resps = {RespSlverr, RespOkay, RespSlverr, RespOkay};
  directed_burst(1'b1, resps);
  resps = {RespOkay, RespOkay, RespOkay, RespSlverr};
  directed_burst(1'b1, resps);
  resps = {RespOkay, RespSlverr, RespSlverr, RespOkay};
  directed_burst(1'b0, resps);
  if (cfg.m_link.m_bridge_decerr) begin
    // DECERR alone, and DECERR and SLVERR in both orders
    resps = {RespDecerr, RespOkay, RespOkay, RespOkay};
    directed_burst(1'b1, resps);
    resps = {RespDecerr, RespSlverr, RespOkay, RespOkay};
    directed_burst(1'b1, resps);
    resps = {RespSlverr, RespDecerr, RespOkay, RespOkay};
    directed_burst(1'b1, resps);
    resps = {RespOkay, RespOkay, RespOkay, RespDecerr};
    directed_burst(1'b1, resps);
    resps = {RespOkay, RespDecerr, RespSlverr, RespOkay};
    directed_burst(1'b0, resps);
  end

  // Beats with no strobes at the start, between strobed beats and in a burst of only such beats
  strbs = {0, full, 0, 1};
  zero_strobe_burst(BurstIncr, strbs);
  zero_strobe_burst(BurstFixed, strbs);
  strbs = {0, 0};
  zero_strobe_burst(BurstIncr, strbs);

  m_run_rsp_seq = 1'b1;
  super.body();
endtask : body
