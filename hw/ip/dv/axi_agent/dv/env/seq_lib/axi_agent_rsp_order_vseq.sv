// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check response policy assignment in acceptance order, with AW before AR at a shared edge.
// Prefetch distinct responses and USER values, then send read-first, write-first and simultaneous
// requests. Transactions after policies run out use defaults. Also check first-response timing with
// fixed latencies.

class axi_agent_rsp_order_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_rsp_order_vseq)

  int unsigned m_num_rounds = 8;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Start the subordinate policy sequence and wait until all items are prefetched
  extern protected task supply(axi_agent_preset_rsp_seq seq);

  // Return a random single-beat request inside the window
  extern protected function axi_agent_rand_req new_single_req();

  // Send a transfer and check that its responses are resp, with USER user
  extern protected task send_expect(axi_agent_rand_req req, bit is_write, axi_resp_e resp,
                                    int unsigned user, string what);

  // Wait for the next AW or AR handshake and return its time
  extern protected task wait_handshake(bit is_write, output time t);

  // For latencies 0, 1, 2 and 5, check BVALID or RVALID is first sampled L + 1 edges after the
  // later AW/W handshake or AR handshake. Exercise both W-before-AW and AW-before-W.
  extern protected task check_latencies();
endclass : axi_agent_rsp_order_vseq


function axi_agent_rsp_order_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_rsp_order_vseq::supply(axi_agent_preset_rsp_seq seq);
  cfg.m_rsp_seqs[0].push_back(seq);
  fork
    seq.start(p_sequencer.m_sub_sequencer);
  join_none
  wait (seq.m_sent == seq.m_items.size());
endtask : supply

function axi_agent_rand_req axi_agent_rsp_order_vseq::new_single_req();
  axi_agent_rand_req req = axi_agent_rand_req::type_id::create("req");

  req.set_bus(cfg);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(req, m_len == 0;)
  return req;
endfunction : new_single_req

task axi_agent_rsp_order_vseq::send_expect(axi_agent_rand_req req, bit is_write, axi_resp_e resp,
                                           int unsigned user, string what);
  axi_transfer_seq seq;
  int unsigned     user_mask = (1 << cfg.m_user_width) - 1;

  send(req, is_write, seq);
  foreach (seq.m_responses[n]) begin
    if (seq.m_responses[n].m_resp != resp || (seq.m_responses[n].m_user & user_mask) !=
        (user & user_mask)) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s: the %0s got response %0d with USER 0x%0h, not %0s with 0x%0h.",
                           what, is_write ? "write" : "read", seq.m_responses[n].m_resp,
                           seq.m_responses[n].m_user, resp.name(), user & user_mask))
    end
  end
endtask : send_expect

task axi_agent_rsp_order_vseq::wait_handshake(bit is_write, output time t);
  axi_vif_t vif = p_sequencer.m_sub_agent.get_vif();

  forever begin
    if (is_write) begin
      @(vif.aw_if.mon_cb);
      if (vif.aw_if.mon_cb.awvalid === 1'b1 && vif.aw_if.mon_cb.awready === 1'b1) begin
        break;
      end
    end else begin
      @(vif.ar_if.mon_cb);
      if (vif.ar_if.mon_cb.arvalid === 1'b1 && vif.ar_if.mon_cb.arready === 1'b1) begin
        break;
      end
    end
  end
  t = $time;
endtask : wait_handshake

task axi_agent_rsp_order_vseq::check_latencies();
  int unsigned               latencies[4] = '{0, 1, 2, 5};
  string                     kinds[3] = '{"write whose W came first", "write whose AW came first",
                                          "read"};
  virtual axi_agent_probe_if probe = cfg.m_probe_vif;
  axi_sub_agent_cfg          sub_cfg = cfg.m_sub_agent_cfgs[0];

  foreach (latencies[i]) begin
    // 0: a write whose AW waits for AWREADY, 1: a write whose W beat waits for WREADY, 2: a read
    for (int unsigned kind = 0; kind < 3; kind++) begin
      axi_agent_preset_rsp_seq seq = axi_agent_preset_rsp_seq::type_id::create("latency");
      bit                      is_write = (kind < 2);
      string                   what;
      int unsigned             start_edge, valid_edge;

      what = $sformatf("A %0s with latency %0d", kinds[kind], latencies[i]);
      set_sub_ready(1'b0);
      if (is_write) begin
        axi_sub_ready_cfg held = (kind == 0) ? sub_cfg.m_aw_ready : sub_cfg.m_w_ready;

        held.m_ready_before_valid_pct = 0;
        held.m_min_valid_to_ready     = 3;
        held.m_max_valid_to_ready     = 3;
      end
      seq.add_item(RespOkay, 0, latencies[i]);
      supply(seq);
      wait_ready();
      send_expect(new_single_req(), is_write, RespOkay, 0, what);

      // Wait one more edge for probe counts to update
      @(posedge cfg.clk_rst_vif.clk);
      if (is_write) begin
        if ((kind == 0 && probe.m_w_hs_edge >= probe.m_aw_hs_edge) ||
            (kind == 1 && probe.m_aw_hs_edge >= probe.m_w_hs_edge)) begin
          `uvm_error(get_full_name(),
                     $sformatf("%0s had its AW at edge %0d and its W at edge %0d.", what,
                               probe.m_aw_hs_edge, probe.m_w_hs_edge))
        end
        start_edge = (probe.m_aw_hs_edge > probe.m_w_hs_edge) ? probe.m_aw_hs_edge :
                                                                probe.m_w_hs_edge;
        valid_edge = probe.m_b_valid_edge;
      end else begin
        start_edge = probe.m_ar_hs_edge;
        valid_edge = probe.m_r_valid_edge;
      end
      if (valid_edge != start_edge + latencies[i] + 1) begin
        `uvm_error(get_full_name(),
                   $sformatf({"%0s became answerable at edge %0d, so its response was due at ",
                              "edge %0d, but was first valid at edge %0d."},
                             what, start_edge, start_edge + latencies[i] + 1, valid_edge))
      end
    end
  end
  set_sub_ready(1'b0);
endtask : check_latencies

task axi_agent_rsp_order_vseq::body();
  // Keep READY high so requests presented together are accepted together
  set_sub_ready(1'b0);
  need("same_edge_accepts", m_num_rounds);
  need("policies_applied", 4 * m_num_rounds);

  for (int unsigned round = 0; round < m_num_rounds; round++) begin
    int unsigned             user = 2 * round + 1;
    axi_agent_preset_rsp_seq seq;
    time                     t_aw, t_ar;

    // A read first, which takes the item, then a write, which takes the defaults
    seq = axi_agent_preset_rsp_seq::type_id::create("read_first");
    seq.add_item(RespSlverr, user);
    supply(seq);
    wait_ready();
    send_expect(new_single_req(), 1'b0, RespSlverr, user, "read first");
    send_expect(new_single_req(), 1'b1, RespOkay, 0, "write after the item ran out");

    // A write first, which takes the item, then a read, which takes the defaults
    seq = axi_agent_preset_rsp_seq::type_id::create("write_first");
    seq.add_item(RespDecerr, user + 1);
    supply(seq);
    wait_ready();
    send_expect(new_single_req(), 1'b1, RespDecerr, user + 1, "write first");
    send_expect(new_single_req(), 1'b0, RespOkay, 0, "read after the item ran out");

    // A write and a read accepted at one edge: the write takes the first item
    seq = axi_agent_preset_rsp_seq::type_id::create("same_edge");
    seq.add_item(RespSlverr, user);
    seq.add_item(RespDecerr, user + 1);
    supply(seq);
    wait_ready();
    fork
      wait_handshake(1'b1, t_aw);
      wait_handshake(1'b0, t_ar);
      send_expect(new_single_req(), 1'b1, RespSlverr, user, "write at the same edge as a read");
      send_expect(new_single_req(), 1'b0, RespDecerr, user + 1, "read at the same edge as a write");
    join
    if (t_aw != t_ar) begin
      `uvm_error(get_full_name(), $sformatf("The write was accepted at %0t and the read at %0t.",
                                            t_aw, t_ar))
    end
  end
  check_latencies();
endtask : body
