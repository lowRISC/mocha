// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base self-test sequence with parallel random transfers. Delay a transfer while another in flight
// touches the same bytes, so read data remains predictable. Derived sequences configure subordinate
// behavior and required activity. Manager drivers immediately reject items during reset, so wait
// for reset release and one clock edge before each transfer to prevent zero-time loops.

class axi_agent_base_vseq extends dv_base_vseq #(
    .CFG_T               (axi_agent_env_cfg),
    .COV_T               (axi_agent_env_cov),
    .VIRTUAL_SEQUENCER_T (axi_agent_virtual_sequencer)
  );
  `uvm_object_utils(axi_agent_base_vseq)

  typedef bit [AxiMaxAddrWidth-1:0] addr_t;

  // Parallel workers, each sending num_trans transfers
  int unsigned m_num_workers = 4;

  // Write percentage and random-strobe percentage
  int unsigned m_write_pct        = 50;
  int unsigned m_partial_strb_pct = 30;

  // Burst selection (see axi_agent_rand_req). axi_agent_link_cfg also limits WRAP and unaligned
  // FIXED to what the far end accepts. m_long_pct selects INCR bursts over 16 beats.
  bit          m_allow_fixed = 1'b1;
  bit          m_allow_wrap  = 1'b1;
  bit          m_allow_lock  = 1'b0;
  int unsigned m_max_len     = 255;
  int unsigned m_long_pct    = 5;

  // Enable a response policy sequence, disabled by default to exercise configuration-only responses
  bit m_run_rsp_seq = 1'b0;

  // Response policy latency bounds and error percentage
  int unsigned m_latency_min = 0;
  int unsigned m_latency_max = 0;
  int unsigned m_error_pct   = 0;

  // Accept B and R with fixed READY timing: before VALID for back-to-back responses, or
  // m_response_ready_delay edges after VALID when that is nonzero. Otherwise randomize READY timing
  // per transfer.
  bit          m_ready_for_responses  = 1'b0;
  int unsigned m_response_ready_delay = 0;

  // Set to make run_workers stop after the transfers in flight
  bit m_stop_workers = 1'b0;

  // Response sequences per subordinate, retained for post_start cleanup
  protected axi_sub_rsp_seq m_rsp_seqs[$];

  // The byte ranges of the transfers in flight
  local addr_t m_busy_lo[$];
  local addr_t m_busy_hi[$];

  // Held by the write in flight on a link with m_serial_writes
  local semaphore m_write_turn;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
  extern task post_start();

  // Class specific methods

  // Start a response sequence per subordinate that stops after num_items when nonzero and otherwise
  // runs until stopped
  extern protected task run_rsp_seq_nonblocking(int unsigned num_items = 0);

  // Wait until reset is released and a clock edge has passed since, with the bus still out of reset
  // at that edge
  extern protected task wait_ready();

  // Return a random request for the link under test, with the knobs of this sequence
  extern protected function axi_agent_rand_req new_req();

  // Wait until no transfer in flight overlaps req, then mark its bytes busy, and the reverse
  extern protected task reserve(axi_agent_rand_req req);
  extern protected function void unreserve(axi_agent_rand_req req);

  // Send through manager mgr's axi_transfer_seq, record results for the scoreboard, and return the
  // sequence. Report a call made during reset, whose transfer the drivers would drop.
  extern protected task send(input axi_agent_rand_req req, input bit is_write,
                             output axi_transfer_seq seq, input int unsigned mgr = 0);

  // Reserve req's bytes, and the write turn on a link with m_serial_writes, then send req once the
  // bus is ready. A reset can start while the reservation waits, so wait for the bus after it.
  extern protected task reserve_and_send(input axi_agent_rand_req req, input bit is_write,
                                         output axi_transfer_seq seq, input int unsigned mgr = 0);

  // Give the scoreboard a record of what a transfer sequence on manager agent mgr got back
  extern protected function void record(axi_transfer_seq seq, int unsigned mgr);

  // Send one transfer once the bus is ready, and check that every response to it is exp_resp
  extern protected task send_expect(axi_agent_rand_req req, bit is_write, axi_resp_e exp_resp,
                                    string what);

  // Send num randomized axi_transfer_seq, axi_single_write_seq and axi_single_read_seq instances in
  // turn, serially on the first manager. Use only set_bus_properties() constraints. Check that all
  // burst bytes fit the address width and, below 64 bits, an address past the bus maximum is
  // rejected. ARUSER is one bit narrower than AWUSER meanwhile, so USER must fit both.
  extern protected task send_bus_seqs(int unsigned num);

  // Send one random write or read, once the bus is out of reset
  extern protected task random_txn();

  // Send num_trans random transfers from each of m_num_workers workers, in parallel
  extern protected task run_workers();

  // Choose always-ready or random AWREADY, WREADY and ARREADY, including READY before VALID and
  // delayed READY
  extern protected function void set_sub_ready(bit random_ready);

  // Require the activity count name (see axi_agent_scoreboard::get_count) to reach at least n
  extern protected function void need(string name, int unsigned n);

  // Enough traffic to read previously written bytes regularly
  extern constraint num_trans_c;
endclass : axi_agent_base_vseq


function axi_agent_base_vseq::new(string name = "");
  super.new(name);
  m_write_turn = new(1);
endfunction : new

task axi_agent_base_vseq::body();
  if (m_run_rsp_seq && m_rsp_seqs.size() == 0) begin
    run_rsp_seq_nonblocking();
  end
  run_workers();
endtask : body

task axi_agent_base_vseq::post_start();
  foreach (m_rsp_seqs[i]) begin
    m_rsp_seqs[i].stop();
  end
  super.post_start();
endtask : post_start

task axi_agent_base_vseq::run_rsp_seq_nonblocking(int unsigned num_items = 0);
  foreach (p_sequencer.m_sub_sequencers[i]) begin
    axi_sub_rsp_seq seq = axi_sub_rsp_seq::type_id::create($sformatf("m_rsp_seqs[%0d]", i));

    seq.m_latency_min = m_latency_min;
    seq.m_latency_max = m_latency_max;
    seq.m_error_pct   = m_error_pct;
    seq.m_num_items   = num_items;
    m_rsp_seqs.push_back(seq);

    cfg.m_rsp_seqs[i].push_back(seq);
    fork
      automatic int unsigned sub = i;

      seq.start(p_sequencer.m_sub_sequencers[sub]);
    join_none
  end
endtask : run_rsp_seq_nonblocking

task axi_agent_base_vseq::wait_ready();
  // Reset is asserted between edges, so check it again at the edge
  do begin
    if (cfg.clk_rst_vif.rst_n !== 1'b1) begin
      wait (cfg.clk_rst_vif.rst_n === 1'b1);
    end
    @(posedge cfg.clk_rst_vif.clk);
  end while (cfg.clk_rst_vif.rst_n !== 1'b1);
endtask : wait_ready

function axi_agent_rand_req axi_agent_base_vseq::new_req();
  axi_agent_rand_req req = axi_agent_rand_req::type_id::create("req");

  req.set_bus(cfg);
  req.m_allow_fixed = m_allow_fixed;
  req.m_allow_wrap  = req.m_allow_wrap && m_allow_wrap;
  req.m_allow_lock  = m_allow_lock;
  req.m_max_len     = m_max_len;
  req.m_long_pct    = m_long_pct;
  `DV_CHECK_RANDOMIZE_FATAL(req)
  return req;
endfunction : new_req

task axi_agent_base_vseq::reserve(axi_agent_rand_req req);
  addr_t lo, hi;

  req.get_range(lo, hi);
  forever begin
    bit busy = 1'b0;

    foreach (m_busy_lo[i]) begin
      if (lo <= m_busy_hi[i] && m_busy_lo[i] <= hi) begin
        busy = 1'b1;
        break;
      end
    end
    if (!busy) begin
      break;
    end
    @(posedge cfg.clk_rst_vif.clk);
  end
  m_busy_lo.push_back(lo);
  m_busy_hi.push_back(hi);
endtask : reserve

function void axi_agent_base_vseq::unreserve(axi_agent_rand_req req);
  addr_t lo, hi;

  req.get_range(lo, hi);
  foreach (m_busy_lo[i]) begin
    if (m_busy_lo[i] == lo && m_busy_hi[i] == hi) begin
      m_busy_lo.delete(i);
      m_busy_hi.delete(i);
      return;
    end
  end
endfunction : unreserve

task axi_agent_base_vseq::send(input axi_agent_rand_req req, input bit is_write,
                               output axi_transfer_seq seq, input int unsigned mgr = 0);
  if (cfg.clk_rst_vif.rst_n !== 1'b1) begin
    `uvm_error(get_full_name(), $sformatf("A %0s to 0x%0h was sent during reset.",
                                          is_write ? "write" : "read", req.m_addr))
  end
  seq = axi_transfer_seq::type_id::create("seq");
  seq.set_bus_properties(p_sequencer.m_mgr_agents[mgr].get_vif());
  seq.m_partial_strb_pct = m_partial_strb_pct;
  if (m_ready_for_responses) begin
    int unsigned ready_first_pct = (m_response_ready_delay == 0) ? 100 : 0;

    seq.m_b_accept.m_use_fixed_ready_without_valid_pct = 1'b1;
    seq.m_b_accept.m_fixed_ready_without_valid_pct     = ready_first_pct;
    seq.m_b_accept.m_use_fixed_valid_to_ready_delay    = 1'b1;
    seq.m_b_accept.m_fixed_valid_to_ready_delay        = m_response_ready_delay;
    seq.m_r_accept.m_use_fixed_ready_without_valid_pct = 1'b1;
    seq.m_r_accept.m_fixed_ready_without_valid_pct     = ready_first_pct;
    seq.m_r_accept.m_use_fixed_valid_to_ready_delay    = 1'b1;
    seq.m_r_accept.m_fixed_valid_to_ready_delay        = m_response_ready_delay;
  end
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_write  == local::is_write;
                                 m_req.m_id     == local::req.m_id;
                                 m_req.m_addr   == local::req.m_addr;
                                 m_req.m_len    == local::req.m_len;
                                 m_req.m_size   == local::req.m_size;
                                 m_req.m_burst  == local::req.m_burst;
                                 m_req.m_lock   == local::req.m_lock;
                                 m_req.m_cache  == local::req.m_cache;
                                 m_req.m_prot   == local::req.m_prot;
                                 m_req.m_qos    == local::req.m_qos;
                                 m_req.m_region == local::req.m_region;
                                 m_req.m_user   == local::req.m_user;)
  seq.start(p_sequencer.m_mgr_sequencers[mgr]);
  record(seq, mgr);
endtask : send

function void axi_agent_base_vseq::record(axi_transfer_seq seq, int unsigned mgr);
  if (cfg.m_mgr_records) begin
    axi_agent_mgr_txn txn = axi_agent_mgr_txn::type_id::create("txn");

    txn.set_from_seq(seq, mgr);
    p_sequencer.m_mgr_driver_txn_port.write(txn);
  end
endfunction : record

task axi_agent_base_vseq::reserve_and_send(input axi_agent_rand_req req, input bit is_write,
                                           output axi_transfer_seq seq, input int unsigned mgr = 0);
  bit is_serial = is_write && cfg.m_link.m_serial_writes;

  reserve(req);
  if (is_serial) begin
    m_write_turn.get(1);
  end
  wait_ready();
  send(req, is_write, seq, mgr);
  if (is_serial) begin
    m_write_turn.put(1);
  end
  unreserve(req);
endtask : reserve_and_send

task axi_agent_base_vseq::send_expect(axi_agent_rand_req req, bit is_write, axi_resp_e exp_resp,
                                      string what);
  axi_transfer_seq seq;

  wait_ready();
  send(req, is_write, seq);
  foreach (seq.m_responses[n]) begin
    if (seq.m_responses[n].m_resp != exp_resp) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s: response %0d to %0s 0x%0h with ID 0x%0h was %0d, not %0s.", what,
                           n, is_write ? "write" : "read", req.m_addr, req.m_id,
                           seq.m_responses[n].m_resp, exp_resp.name()))
    end
  end
endtask : send_expect

task axi_agent_base_vseq::send_bus_seqs(int unsigned num);
  axi_vif_t    vif = p_sequencer.m_mgr_agents[0].get_vif();
  int unsigned bus_bytes = cfg.m_data_width / 8;
  int unsigned user_width = vif.ar_if.user_req_width;

  // Change the width at an edge, while no transfer is in flight
  if (user_width > 0) begin
    wait_ready();
    vif.ar_if.set_user_req_width(user_width - 1);
  end
  for (int unsigned i = 0; i < num; i++) begin
    axi_transfer_seq     seq;
    axi_single_write_seq wr_seq;
    axi_single_read_seq  rd_seq;

    case (i % 3)
      0: begin
        seq = axi_transfer_seq::type_id::create("seq");
      end
      1: begin
        wr_seq = axi_single_write_seq::type_id::create("wr_seq");
        seq    = wr_seq;
      end
      default: begin
        rd_seq = axi_single_read_seq::type_id::create("rd_seq");
        seq    = rd_seq;
      end
    endcase
    seq.set_bus_properties(vif);
    `DV_CHECK_RANDOMIZE_FATAL(seq)

    // Compute each beat's last byte with pulp_axi equations, independently of the sequence
    // constraints
    for (int unsigned n = 0; n <= seq.m_req.m_len && cfg.m_addr_width < AxiMaxAddrWidth; n++) begin
      addr_t       beat_addr;
      int unsigned lower, upper;

      beat_lanes(seq.m_req.m_addr, seq.m_req.m_size, seq.m_req.m_len, seq.m_req.m_burst,
                 bus_bytes, n, beat_addr, lower, upper);
      if (((beat_addr - beat_addr % bus_bytes + upper) >> cfg.m_addr_width) != 0) begin
        `uvm_error(get_full_name(),
                   $sformatf({"%0s at 0x%0h, AxLEN %0d, AxSIZE %0d: beat %0d has bytes past the ",
                              "%0d bit address bus."},
                             seq.get_type_name(), seq.m_req.m_addr, seq.m_req.m_len,
                             seq.m_req.m_size, n, cfg.m_addr_width))
      end
    end

    wait_ready();
    seq.start(p_sequencer.m_mgr_sequencers[0]);
    if (!seq.has_full_transaction()) begin
      `uvm_error(get_full_name(), $sformatf("%0s at 0x%0h did not complete.", seq.get_type_name(),
                                            seq.m_req.m_addr))
    end
    record(seq, 0);
  end
  if (user_width > 0) begin
    @(posedge cfg.clk_rst_vif.clk);
    vif.ar_if.set_user_req_width(user_width);
  end

  // Check rejection of an address past the bus maximum
  if (cfg.m_addr_width < AxiMaxAddrWidth) begin
    axi_single_read_seq seq = axi_single_read_seq::type_id::create("past_top_seq");

    seq.set_bus_properties(vif);
    `DV_CHECK_RANDOMIZE_FATAL(seq)
    seq.m_req.m_addr = addr_t'(1) << cfg.m_addr_width;
    `uvm_info(get_full_name(),
              $sformatf({"Checking that the constraints reject a read at 0x%0h. The simulator may ",
                         "report the randomize call that fails."}, seq.m_req.m_addr), UVM_LOW)
    if (seq.randomize(null)) begin
      `uvm_error(get_full_name(),
                 $sformatf("A read at 0x%0h met the constraints of a bus with %0d address bits.",
                           seq.m_req.m_addr, cfg.m_addr_width))
    end
  end
endtask : send_bus_seqs

task axi_agent_base_vseq::random_txn();
  axi_transfer_seq seq;
  bit              is_write = ($urandom_range(0, 99) < m_write_pct);
  int unsigned     mgr = $urandom_range(0, cfg.m_link.m_num_mgrs - 1);

  reserve_and_send(new_req(), is_write, seq, mgr);
endtask : random_txn

task axi_agent_base_vseq::run_workers();
  // Isolate wait fork to these workers
  fork
    begin
      for (int unsigned w = 0; w < m_num_workers; w++) begin
        fork
          begin
            for (int unsigned t = 0; t < num_trans && !m_stop_workers; t++) begin
              random_txn();
            end
          end
        join_none
      end
      wait fork;
    end
  join
endtask : run_workers

function void axi_agent_base_vseq::set_sub_ready(bit random_ready);
  foreach (cfg.m_sub_agent_cfgs[s]) begin
    axi_sub_ready_cfg ready_cfgs[3] = '{cfg.m_sub_agent_cfgs[s].m_aw_ready,
                                        cfg.m_sub_agent_cfgs[s].m_w_ready,
                                        cfg.m_sub_agent_cfgs[s].m_ar_ready};

    foreach (ready_cfgs[i]) begin
      if (random_ready) begin
        ready_cfgs[i].m_ready_before_valid_pct = $urandom_range(20, 80);
        ready_cfgs[i].m_min_valid_to_ready     = $urandom_range(0, 2);
        ready_cfgs[i].m_max_valid_to_ready     = ready_cfgs[i].m_min_valid_to_ready +
                                                 $urandom_range(1, 6);
      end else begin
        ready_cfgs[i].m_ready_before_valid_pct = 100;
        ready_cfgs[i].m_min_valid_to_ready     = 0;
        ready_cfgs[i].m_max_valid_to_ready     = 0;
      end
    end
  end
endfunction : set_sub_ready

function void axi_agent_base_vseq::need(string name, int unsigned n);
  cfg.m_min_counts[name] = n;
endfunction : need

constraint axi_agent_base_vseq::num_trans_c {
  num_trans inside {[30:50]};
}
