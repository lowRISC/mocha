// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Expected failures for pulp_axi violations of AMBA AXI H.c, each on a tb.sv link with the failing
// check named below. Exclude from the default regression. Override link or testbench settings that
// avoid these defects in other tests (see axi_agent_link_cfg).


// Exclusive and WRAP axi_rand_master reproducers use axi_agent_pulp_mgr_vseq on pulp_mgr with
// +pulp_mgr_kind=excl or wrap


// On rand_slave, +pulp_repro_ar_4kb drives two illegal read bursts from tb.sv. ArRequestLegal_A
// catches both, but AXI_BUS_DV checks AR's 4KB rule only when AWBURST is INCR and catches only the
// second.
class axi_agent_pulp_repro_ar_4kb_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_ar_4kb_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_ar_4kb_vseq


function axi_agent_pulp_repro_ar_4kb_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_ar_4kb_vseq::body();
  // tb.sv drives the bursts, so the scoreboard has nothing to predict. Disable it.
  cfg.en_scb = 1'b0;
  wait (cfg.m_pulp_ctrl_vif.ops_done == 1);
endtask : body


// axi_lite_rand_slave on lite_rand_slave returns EXOKAY, forbidden in AXI4-Lite (H.c B1.1).
// LiteNoBExOkay_A and LiteNoRExOkay_A fail.
class axi_agent_pulp_repro_lite_rand_slave_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_lite_rand_slave_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_lite_rand_slave_vseq


function axi_agent_pulp_repro_lite_rand_slave_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_lite_rand_slave_vseq::body();
  num_trans = 20;
  super.body();
endtask : body


// Reset rand_slave while VALID waits for READY. AXI_BUS_DV incorrectly requires VALID to remain
// high during reset, contrary to A3.1.2, and fails.
class axi_agent_pulp_repro_rand_slave_reset_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_rand_slave_reset_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_rand_slave_reset_vseq


function axi_agent_pulp_repro_rand_slave_reset_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_rand_slave_reset_vseq::body();
  axi_vif_t vif = p_sequencer.m_mgr_agent.get_vif();

  num_trans = 100_000;
  fork
    super.body();
    begin
      do begin
        @(vif.aw_if.mon_cb);
      end while (!(vif.aw_if.mon_cb.awvalid === 1'b1 && vif.aw_if.mon_cb.awready !== 1'b1));
      `uvm_info(get_full_name(), "Resetting the bus while AWVALID waits for AWREADY", UVM_LOW)
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(5));
      m_stop_workers = 1'b1;
    end
  join
endtask : body


// On rand_slave, exclusive read beats mix OKAY and EXOKAY, violating A7.2.5 (RNoOkayExOkayMix_A).
// After an EXOKAY read, the slave carries out an exclusive write answered OKAY, and readback
// catches the memory change forbidden by A7.2.3.
class axi_agent_pulp_repro_rand_slave_excl_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_rand_slave_excl_vseq)

  int unsigned m_num_rounds = 20;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_rand_slave_excl_vseq


function axi_agent_pulp_repro_rand_slave_excl_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_rand_slave_excl_vseq::body();
  repeat (m_num_rounds) begin
    axi_agent_rand_req req = axi_agent_rand_req::type_id::create("req");
    axi_transfer_seq   rd, wr, check;
    bit                read_exokay = 1'b1;

    req.set_bus(cfg);
    req.m_allow_lock = 1'b1;
    `DV_CHECK_RANDOMIZE_WITH_FATAL(req, m_lock == 1'b1; m_len inside {[1:3]};)

    wait_ready();
    send(req, 1'b0, rd);
    foreach (rd.m_responses[n]) begin
      read_exokay &= (rd.m_responses[n].m_resp == RespExOkay);
    end
    send(req, 1'b1, wr);
    send(req, 1'b0, check);
    if (read_exokay && wr.m_responses[0].m_resp == RespOkay) begin
      foreach (check.m_responses[n]) begin
        if (check.m_responses[n].m_rdata !== rd.m_responses[n].m_rdata) begin
          `uvm_error(get_full_name(),
                     $sformatf({"Beat %0d at 0x%0h changed from 0x%0h to 0x%0h after an exclusive ",
                                "write that was answered OKAY following an EXOKAY read."},
                               n, req.m_addr, rd.m_responses[n].m_rdata,
                               check.m_responses[n].m_rdata))
        end
      end
    end
  end
endtask : body


// On pulp_lite_mgr, +pulp_lite_rand sends strobes below unaligned addresses, violating A3.4.4.
// WStrbOnBeatLanes_A fails.
class axi_agent_pulp_repro_lite_rand_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_lite_rand_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_lite_rand_vseq


function axi_agent_pulp_repro_lite_rand_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_lite_rand_vseq::body();
  wait_ready();
  cfg.m_pulp_ctrl_vif.n_reads  = 50;
  cfg.m_pulp_ctrl_vif.n_writes = 50;
  cfg.m_pulp_ctrl_vif.start    = 1'b1;
  wait (cfg.m_pulp_ctrl_vif.runs_done == 1);
endtask : body


// On sim_mem, unaligned FIXED bursts start one byte into an eight-byte container below the SLVERR
// page. All beats use the first beat's lanes (A3.4.2), outside the page, but axi_sim_mem widens
// later beats into it. The scoreboard catches unexpected SLVERR.
class axi_agent_pulp_repro_sim_mem_fixed_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_sim_mem_fixed_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_sim_mem_fixed_vseq


function axi_agent_pulp_repro_sim_mem_fixed_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_sim_mem_fixed_vseq::body();
  axi_agent_rand_req req = axi_agent_rand_req::type_id::create("req");
  axi_transfer_seq   seq;

  req.set_bus(cfg);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(req, m_len == 3; m_size == 3; m_burst == BurstFixed;
                                 m_lock == 1'b0;)
  req.m_addr = SimMemSlverrPage - 7;
  wait_ready();
  send(req, 1'b1, seq);
  send(req, 1'b0, seq);
endtask : body


// On rand_slave with +axi_link_serial_writes=0, hold the first B response with three writes
// outstanding. axi_rand_slave writes the third at the second's address, so readback fails in the
// scoreboard.
class axi_agent_pulp_repro_rand_slave_held_b_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_pulp_repro_rand_slave_held_b_vseq)

  // The cycles that the manager holds BREADY low for the first write
  int unsigned m_hold_cycles = 100;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_agent_pulp_repro_rand_slave_held_b_vseq


function axi_agent_pulp_repro_rand_slave_held_b_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_pulp_repro_rand_slave_held_b_vseq::body();
  axi_agent_rand_req reqs[3];
  axi_transfer_seq   seq;

  // The first write has no sequence record, so disable record comparisons
  cfg.m_mgr_records = 1'b0;

  foreach (reqs[i]) begin
    reqs[i] = axi_agent_rand_req::type_id::create($sformatf("req_%0d", i));
    reqs[i].set_bus(cfg);
    `DV_CHECK_RANDOMIZE_WITH_FATAL(reqs[i], m_len == 0; m_size == 3; m_burst == BurstIncr;
                                   m_lock == 1'b0;)
    reqs[i].m_addr = AxiWinBase + 32'h100 * (i + 1);
  end

  wait_ready();
  fork
    begin
      axi_transfer_seq held = axi_transfer_seq::type_id::create("held");

      held.set_bus_properties(p_sequencer.m_mgr_agent.get_vif());
      held.m_b_accept.m_use_fixed_ready_without_valid_pct = 1'b1;
      held.m_b_accept.m_fixed_ready_without_valid_pct     = 0;
      held.m_b_accept.m_use_fixed_valid_to_ready_delay    = 1'b1;
      held.m_b_accept.m_fixed_valid_to_ready_delay        = m_hold_cycles;
      `DV_CHECK_RANDOMIZE_WITH_FATAL(held,
                                     m_write  == 1'b1;
                                     m_req.m_id     == local::reqs[0].m_id;
                                     m_req.m_addr   == local::reqs[0].m_addr;
                                     m_req.m_len    == 0;
                                     m_req.m_size   == 3;
                                     m_req.m_burst  == BurstIncr;
                                     m_req.m_lock   == 1'b0;)
      held.start(p_sequencer.m_mgr_sequencer);
    end
    begin
      axi_transfer_seq second;

      cfg.clk_rst_vif.wait_clks(10);
      send(reqs[1], 1'b1, second);
    end
    begin
      axi_transfer_seq third;

      cfg.clk_rst_vif.wait_clks(20);
      send(reqs[2], 1'b1, third);
    end
  join

  foreach (reqs[i]) begin
    send(reqs[i], 1'b0, seq);
  end
endtask : body
