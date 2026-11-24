// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Reset during traffic, dropping all outstanding transactions (AMBA AXI H.c A3.1.2). Assertions
// check VALID low during and immediately after reset, and the scoreboard rejects pre-reset
// responses. Aborted writes leave bytes unknown until rewritten. Finally, reset under a write that
// another write to the same bytes waits behind, then during the second start of a reused write
// sequence, then during the second starts of reused B and R accept sequences. Then start a write
// and a read in the time step where reset is released. Last, reset for less than a clock period
// under stalled AW, W and AR requests.

class axi_agent_reset_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_reset_vseq)

  // The number of resets in the middle of traffic, and the clock cycles of traffic before each
  int unsigned m_num_resets                = 4;
  int unsigned m_cycles_between_resets_min = 200;
  int unsigned m_cycles_between_resets_max = 1000;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Hold a write at AWREADY low, queue a second write on its reserved bytes, and reset. The second
  // write must be sent after reset release and complete.
  extern protected task write_queued_across_reset();

  // Start a write sequence twice. Hold AWREADY low and reset during the second start. Require only
  // the second request and no response in its results.
  extern protected task reused_seq_cut_by_reset();

  // Start B and R accept sequences twice. Each first start must take a write or read response.
  // Reset aborts the idle second starts, which must return no response and take no handshake.
  extern protected task reused_accepts_cut_by_reset();

  // Start a write and a read in the time step where reset is released, which is a clock edge (H.c
  // A3.1.2). The drivers must hold VALID low until the next edge, and both must complete.
  extern protected task send_at_release();

  // Stall AW, W and AR with VALID high, assert reset between edges and release it at the next edge.
  // No VALID may rise before an edge has sampled the release (H.c A3.1.2), not even for a delta
  // cycle when the release unmasks the interfaces.
  extern protected task short_reset_under_stall();
endclass : axi_agent_reset_vseq


function axi_agent_reset_vseq::new(string name = "");
  super.new(name);
  m_run_rsp_seq = 1'b1;
  m_latency_max = 8;
endfunction : new

task axi_agent_reset_vseq::body();
  // The workers run until the resets are done
  num_trans = 100_000;
  set_sub_ready(1'b1);
  need("resets", m_num_resets);
  need("writes_cut_by_reset", 1);

  fork
    super.body();
    begin
      repeat (m_num_resets) begin
        int unsigned cycles;

        `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(
            cycles,
            cycles inside {[m_cycles_between_resets_min:m_cycles_between_resets_max]};)
        cfg.clk_rst_vif.wait_clks(cycles);

        // Wait a bounded time for an open write, then reset to abort it
        for (int unsigned waited = 0;
             cfg.m_probe_vif.m_writes_open.size() == 0 && waited < m_cycles_between_resets_max;
             waited++) begin
          cfg.clk_rst_vif.wait_clks(1);
        end
        `uvm_info(get_full_name(), "Resetting the bus underneath the traffic", UVM_LOW)
        cfg.clk_rst_vif.apply_reset(.reset_width_clks($urandom_range(5, 20)));
      end
      cfg.clk_rst_vif.wait_clks(m_cycles_between_resets_min);
      m_stop_workers = 1'b1;
    end
  join
  write_queued_across_reset();
  reused_seq_cut_by_reset();
  reused_accepts_cut_by_reset();
  send_at_release();
  short_reset_under_stall();
endtask : body

task axi_agent_reset_vseq::write_queued_across_reset();
  axi_agent_rand_req req = new_req();
  axi_transfer_seq   held_seq, queued_seq;
  int unsigned       aw_handshakes;

  req.m_len   = 0;
  req.m_burst = BurstIncr;
  req.m_lock  = 1'b0;

  // Hold AWREADY low until reset to keep the first write pending
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    cfg.m_sub_agent_cfgs[s].m_aw_ready.m_ready_before_valid_pct = 0;
    cfg.m_sub_agent_cfgs[s].m_aw_ready.m_min_valid_to_ready     = 1000;
    cfg.m_sub_agent_cfgs[s].m_aw_ready.m_max_valid_to_ready     = 1000;
  end
  wait_ready();
  fork
    reserve_and_send(req, 1'b1, held_seq);
    begin
      // Start once the first write holds the bytes
      cfg.clk_rst_vif.wait_clks(1);
      reserve_and_send(req, 1'b1, queued_seq);
    end
    begin
      cfg.clk_rst_vif.wait_clks(20);
      `uvm_info(get_full_name(), "Resetting the bus under a write that another write waits behind",
                UVM_LOW)
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(10));
      set_sub_ready(1'b1);
      aw_handshakes = cfg.m_probe_vif.m_aw_handshakes;
    end
  join
  if (!queued_seq.has_full_transaction() ||
      cfg.m_probe_vif.m_aw_handshakes != aw_handshakes + 1) begin
    `uvm_error(get_full_name(),
               $sformatf({"The write queued behind a write cut by reset took %0d AW handshakes ",
                          "after reset release and has_full_transaction() %0b: expected 1 and 1."},
                         cfg.m_probe_vif.m_aw_handshakes - aw_handshakes,
                         queued_seq.has_full_transaction()))
  end
endtask : write_queued_across_reset

task axi_agent_reset_vseq::reused_seq_cut_by_reset();
  axi_agent_rand_req req = new_req();
  axi_transfer_seq   seq;

  req.m_len   = 0;
  req.m_burst = BurstIncr;
  req.m_lock  = 1'b0;
  wait_ready();
  send(req, 1'b1, seq);
  if (!seq.has_full_transaction()) begin
    `uvm_error(get_full_name(), "The first start of the reused write did not complete.")
  end

  // Hold AWREADY low until reset to keep the request pending
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    cfg.m_sub_agent_cfgs[s].m_aw_ready.m_ready_before_valid_pct = 0;
    cfg.m_sub_agent_cfgs[s].m_aw_ready.m_min_valid_to_ready     = 1000;
    cfg.m_sub_agent_cfgs[s].m_aw_ready.m_max_valid_to_ready     = 1000;
  end
  wait_ready();
  fork
    seq.start(p_sequencer.m_mgr_sequencers[0]);
    begin
      cfg.clk_rst_vif.wait_clks(20);
      `uvm_info(get_full_name(), "Resetting the bus under the second start of a reused write",
                UVM_LOW)
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(10));
    end
  join
  record(seq, 0);
  if (seq.has_full_transaction() || seq.m_requests.size() != 1 || seq.m_responses.size() != 0) begin
    `uvm_error(get_full_name(),
               $sformatf({"The second start of a reused write, cut by reset, ended with %0d ",
                          "requests and %0d responses, and has_full_transaction() %0b: expected ",
                          "1, 0 and 0."},
                         seq.m_requests.size(), seq.m_responses.size(),
                         seq.has_full_transaction()))
  end
  set_sub_ready(1'b1);
  wait_ready();
endtask : reused_seq_cut_by_reset

task axi_agent_reset_vseq::reused_accepts_cut_by_reset();
  axi_mgr_agent                 agent = p_sequencer.m_mgr_agent;
  int unsigned                  bus_bytes = cfg.m_data_width / 8;
  axi_agent_rand_req            wr_req = new_req();
  axi_agent_rand_req            rd_req = new_req();
  axi_mgr_txn_request_seq       aw_seq = axi_mgr_txn_request_seq::type_id::create("aw_seq");
  axi_mgr_write_listed_data_seq w_seq = axi_mgr_write_listed_data_seq::type_id::create("w_seq");
  axi_mgr_txn_request_seq       ar_seq = axi_mgr_txn_request_seq::type_id::create("ar_seq");
  axi_mgr_write_response_seq    b_seq = axi_mgr_write_response_seq::type_id::create("b_seq");
  axi_mgr_read_data_seq         r_seq = axi_mgr_read_data_seq::type_id::create("r_seq");
  axi_write_data_item           beat = axi_write_data_item::type_id::create("beat");
  bit [AxiMaxAddrWidth-1:0]     beat_addr;
  int unsigned                  lower, upper;
  int unsigned                  b_handshakes, r_handshakes;
  bit                           mgr_records = cfg.m_mgr_records;

  // Direct channel accepts have no axi_transfer_seq records for scoreboard comparison
  cfg.m_mgr_records = 1'b0;

  wr_req.m_len   = 0;
  wr_req.m_burst = BurstIncr;
  wr_req.m_lock  = 1'b0;
  rd_req.m_len   = 0;
  rd_req.m_burst = BurstIncr;
  rd_req.m_lock  = 1'b0;
  aw_seq.m_req   = wr_req;
  ar_seq.m_req   = rd_req;
  axi_beat_lanes(wr_req.m_addr, wr_req.m_size, wr_req.m_len, wr_req.m_burst, bus_bytes, 0,
                 beat_addr, lower, upper);
  beat.m_data = '0;
  beat.m_strb = '0;
  beat.m_user = '0;
  for (int unsigned lane = lower; lane <= upper; lane++) begin
    beat.m_data[8 * lane +: 8] = $urandom();
    beat.m_strb[lane]          = 1'b1;
  end
  w_seq.m_items.push_back(beat);
  `DV_CHECK_RANDOMIZE_FATAL(w_seq)

  wait_ready();
  fork
    aw_seq.start(agent.get_write_request_sequencer());
    w_seq.start(agent.get_write_data_sequencer());
  join
  b_seq.start(agent.get_write_response_sequencer());
  ar_seq.start(agent.get_read_request_sequencer());
  r_seq.start(agent.get_read_data_sequencer());
  if (b_seq.rsp == null || r_seq.rsp == null) begin
    `uvm_error(get_full_name(),
               $sformatf({"The first starts of the reused B and R accepts returned %0s B ",
                          "response and %0s R response: expected one each."},
                         b_seq.rsp == null ? "no" : "a", r_seq.rsp == null ? "no" : "an"))
  end

  // Nothing is outstanding, so only reset ends the second starts
  b_handshakes = cfg.m_probe_vif.m_b_handshakes;
  r_handshakes = cfg.m_probe_vif.m_r_handshakes;
  fork
    b_seq.start(agent.get_write_response_sequencer());
    r_seq.start(agent.get_read_data_sequencer());
    begin
      cfg.clk_rst_vif.wait_clks(20);
      `uvm_info(get_full_name(),
                "Resetting the bus under the second starts of reused B and R accepts", UVM_LOW)
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(10));
    end
  join
  if (b_seq.rsp != null || r_seq.rsp != null ||
      cfg.m_probe_vif.m_b_handshakes != b_handshakes ||
      cfg.m_probe_vif.m_r_handshakes != r_handshakes) begin
    `uvm_error(get_full_name(),
               $sformatf({"The second starts of the reused B and R accepts, cut by reset, took ",
                          "%0d B and %0d R handshakes and returned %0s B response and %0s R ",
                          "response: expected none."},
                         cfg.m_probe_vif.m_b_handshakes - b_handshakes,
                         cfg.m_probe_vif.m_r_handshakes - r_handshakes,
                         b_seq.rsp == null ? "no" : "a", r_seq.rsp == null ? "no" : "an"))
  end
  wait_ready();

  // The transfers that follow have records again
  cfg.m_mgr_records = mgr_records;
endtask : reused_accepts_cut_by_reset

task axi_agent_reset_vseq::send_at_release();
  axi_agent_rand_req        write_req = new_req();
  axi_agent_rand_req        read_req;
  axi_transfer_seq          write_seq, read_seq;
  bit [AxiMaxAddrWidth-1:0] write_lo, write_hi, read_lo, read_hi;

  // Keep the read off the write's bytes, since the scoreboard predicts its data
  write_req.get_range(write_lo, write_hi);
  do begin
    read_req = new_req();
    read_req.get_range(read_lo, read_hi);
  end while (read_lo <= write_hi && write_lo <= read_hi);

  wait_ready();
  reserve(write_req);
  reserve(read_req);
  fork
    begin
      `uvm_info(get_full_name(), "Starting a write and a read as reset is released", UVM_LOW)
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(10));
    end
    begin
      wait (cfg.clk_rst_vif.rst_n === 1'b0);
      wait (cfg.clk_rst_vif.rst_n === 1'b1);
      fork
        send(write_req, 1'b1, write_seq);
        send(read_req, 1'b0, read_seq);
      join
    end
  join
  unreserve(write_req);
  unreserve(read_req);
  if (!write_seq.has_full_transaction() || !read_seq.has_full_transaction()) begin
    `uvm_error(get_full_name(),
               $sformatf({"The write and the read started as reset was released report ",
                          "has_full_transaction() %0b and %0b: expected 1 and 1."},
                         write_seq.has_full_transaction(), read_seq.has_full_transaction()))
  end
endtask : send_at_release

task axi_agent_reset_vseq::short_reset_under_stall();
  axi_mgr_agent                 agent = p_sequencer.m_mgr_agent;
  virtual axi_agent_probe_if    probe = cfg.m_probe_vif;
  int unsigned                  bus_bytes = cfg.m_data_width / 8;
  axi_agent_rand_req            wr_req = new_req();
  axi_agent_rand_req            rd_req = new_req();
  axi_mgr_txn_request_seq       aw_seq = axi_mgr_txn_request_seq::type_id::create("aw_seq");
  axi_mgr_write_listed_data_seq w_seq = axi_mgr_write_listed_data_seq::type_id::create("w_seq");
  axi_mgr_txn_request_seq       ar_seq = axi_mgr_txn_request_seq::type_id::create("ar_seq");
  axi_write_data_item           beat = axi_write_data_item::type_id::create("beat");
  bit [AxiMaxAddrWidth-1:0]     beat_addr;
  int unsigned                  lower, upper;
  bit                           early_rise;
  bit                           mgr_records = cfg.m_mgr_records;

  // Direct channel sequences have no axi_transfer_seq records for scoreboard comparison
  cfg.m_mgr_records = 1'b0;

  wr_req.m_len   = 0;
  wr_req.m_burst = BurstIncr;
  wr_req.m_lock  = 1'b0;
  rd_req.m_len   = 0;
  rd_req.m_burst = BurstIncr;
  rd_req.m_lock  = 1'b0;
  aw_seq.m_req   = wr_req;
  ar_seq.m_req   = rd_req;
  axi_beat_lanes(wr_req.m_addr, wr_req.m_size, wr_req.m_len, wr_req.m_burst, bus_bytes, 0,
                 beat_addr, lower, upper);
  beat.m_data = '0;
  beat.m_strb = '0;
  beat.m_user = '0;
  for (int unsigned lane = lower; lane <= upper; lane++) begin
    beat.m_data[8 * lane +: 8] = $urandom();
    beat.m_strb[lane]          = 1'b1;
  end
  w_seq.m_items.push_back(beat);
  `DV_CHECK_RANDOMIZE_FATAL(w_seq)

  // Hold every READY low until reset, so that the three VALIDs stay high
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    axi_sub_ready_cfg ready_cfgs[3] = '{cfg.m_sub_agent_cfgs[s].m_aw_ready,
                                        cfg.m_sub_agent_cfgs[s].m_w_ready,
                                        cfg.m_sub_agent_cfgs[s].m_ar_ready};

    foreach (ready_cfgs[i]) begin
      ready_cfgs[i].m_ready_before_valid_pct = 0;
      ready_cfgs[i].m_min_valid_to_ready     = 1000;
      ready_cfgs[i].m_max_valid_to_ready     = 1000;
    end
  end
  wait_ready();
  fork
    aw_seq.start(agent.get_write_request_sequencer());
    w_seq.start(agent.get_write_data_sequencer());
    ar_seq.start(agent.get_read_request_sequencer());
    begin
      wait (probe.awvalid === 1'b1 && probe.wvalid === 1'b1 && probe.arvalid === 1'b1);
      @(negedge cfg.clk_rst_vif.clk);
      `uvm_info(get_full_name(), "Resetting the bus for half a clock period under stalled requests",
                UVM_LOW)

      // The three items are cut, so nothing may raise VALID until the next edge has come
      fork
        begin : watch_valid
          @(posedge probe.awvalid or posedge probe.wvalid or posedge probe.arvalid);
          early_rise = 1'b1;
        end
      join_none
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(1),
                                  .rst_n_scheme(common_ifs_pkg::RstAssertSyncDeassertSync));
      @(posedge cfg.clk_rst_vif.clk);
      disable watch_valid;
    end
  join
  if (early_rise) begin
    `uvm_error(get_full_name(),
               "VALID rose before an edge had sampled the release of a half-period reset.")
  end
  if (aw_seq.rsp.m_sending_complete || w_seq.rsp.m_sending_complete ||
      ar_seq.rsp.m_sending_complete) begin
    `uvm_error(get_full_name(),
               $sformatf({"The stalled AW, W and AR items cut by reset report m_sending_complete ",
                          "%0b, %0b and %0b: expected 0, 0 and 0."},
                         aw_seq.rsp.m_sending_complete, w_seq.rsp.m_sending_complete,
                         ar_seq.rsp.m_sending_complete))
  end
  set_sub_ready(1'b1);
  wait_ready();
  cfg.m_mgr_records = mgr_records;
endtask : short_reset_under_stall
