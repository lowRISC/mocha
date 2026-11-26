// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base virtual sequence. Runs on the virtual sequencer and provides the read/write helper API on
// its sequencers and routers. Every per-test vseq extends this.
class axi_sram_base_vseq extends uvm_sequence;
  `uvm_object_utils(axi_sram_base_vseq)
  `uvm_declare_p_sequencer(axi_sram_virtual_sequencer)

  axi_sram_env_cfg cfg;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task pre_start();

  // Class specific methods
  // Reset the DUT, then wait until the AXI agent is also out of reset, so the first
  // transaction is not cut off by it.
  extern protected task await_reset();

  // Build a single write-data beat.
  extern protected function axi_write_data_item make_wd(bit [63:0] data, bit [7:0] strb,
                                                        bit tag, bit last);

  // Hand a write burst its channel sequencers and response router. Separate from run_write for
  // a test that has to start the burst itself.
  extern protected function void wire_write(axi_mgr_write_burst_vseq seq);

  // Drive a prepared write burst and wait for its B response.
  extern protected task run_write(axi_mgr_write_burst_vseq seq, string ctx);

  // Drive a prepared read burst and check the beat count and RLAST. The monitor publishes a read
  // only on RLAST, so a burst without it would never reach the scoreboard.
  extern protected task run_read(axi_mgr_read_burst_vseq seq, string ctx,
                                 int unsigned exp_beats);

  // Single-beat 8-byte write (no CHERI tag).
  extern protected task write_word(bit [31:0] id, bit [63:0] addr, bit [63:0] data);

  // 2-beat capability write (awlen=1, awsize=3, INCR) with WUSER=tag on both beats.
  extern protected task write_cap(bit [31:0] id, bit [63:0] addr,
                                  bit [63:0] lower, bit [63:0] upper, bit tag);

  // Single-beat 8-byte read.
  extern protected task read_word(bit [31:0] id, bit [63:0] addr);

  // 2-beat capability read (arlen=1, arsize=3, INCR).
  extern protected task read_cap(bit [31:0] id, bit [63:0] addr);
endclass : axi_sram_base_vseq


function axi_sram_base_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_sram_base_vseq::pre_start();
  super.pre_start();
  cfg = p_sequencer.cfg;
endtask : pre_start

task axi_sram_base_vseq::await_reset();
  int unsigned stable = 0;
  int unsigned waited = 0;
  cfg.clk_rst_vif.apply_reset();
  while (stable < 20) begin
    cfg.clk_rst_vif.wait_clks(1);
    waited++;
    if (waited > 10000) begin
      `uvm_fatal(get_full_name(), "DUT-side AXI reset (rst_ni) never stabilised high")
    end
    stable = (cfg.axi_vif.u_clk_rst_if.rst_n === 1'b1) ? (stable + 1) : 0;
  end
endtask : await_reset

function axi_write_data_item axi_sram_base_vseq::make_wd(bit [63:0] data, bit [7:0] strb,
                                                         bit tag, bit last);
  axi_write_data_item it = axi_write_data_item::type_id::create("wd");
  it.m_data = 1024'(data);
  it.m_strb = 128'(strb);
  it.m_user = 512'(tag);
  it.m_last = last;
  return it;
endfunction : make_wd

function void axi_sram_base_vseq::wire_write(axi_mgr_write_burst_vseq seq);
  seq.set_write_response_router(p_sequencer.write_response_router);
  seq.set_sequencers(p_sequencer.write_request_seqr,
                     p_sequencer.write_data_seqr,
                     p_sequencer.write_response_seqr);
endfunction : wire_write

task axi_sram_base_vseq::run_write(axi_mgr_write_burst_vseq seq, string ctx);
  // seq arrives fully randomised: the caller constrained the burst it wanted, so m_aw_req is
  // final here (AWLEN solved by len_matches_data_c).
  wire_write(seq);
  seq.start(null);
  if (seq.rsp == null || seq.rsp.m_write_response == null) begin
    `uvm_fatal(get_full_name(), {ctx, ": write completed with null B response (reset?)"})
  end
endtask : run_write

task axi_sram_base_vseq::run_read(axi_mgr_read_burst_vseq seq, string ctx,
                                  int unsigned exp_beats);
  seq.set_read_response_router(p_sequencer.read_response_router);
  seq.set_sequencers(p_sequencer.read_request_seqr, p_sequencer.read_data_seqr);
  seq.start(null);
  if (seq.m_read_beats.size() != exp_beats) begin
    `uvm_fatal(get_full_name(), $sformatf("%s: expected %0d beats, got %0d (reset?)",
               ctx, exp_beats, seq.m_read_beats.size()))
  end
  foreach (seq.m_read_beats[i]) begin
    bit exp_last = (i == exp_beats - 1);
    if (seq.m_read_beats[i].m_last != exp_last) begin
      `uvm_error(get_full_name(), $sformatf("%s: beat %0d RLAST=%0b expected %0b", ctx, i,
                 seq.m_read_beats[i].m_last, exp_last))
    end
  end
  cfg.min_checked_reads++;
endtask : run_read

task axi_sram_base_vseq::write_word(bit [31:0] id, bit [63:0] addr, bit [63:0] data);
  axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("ww");
  // Beats first: len_matches_data_c ties AWLEN to m_data_items.size() during the solve.
  seq.m_data_items.push_back(make_wd(data, 8'hFF, 1'b0, 1'b1));
  if (!seq.randomize() with { m_aw_req.m_id    == id;
                              m_aw_req.m_addr  == local::addr;
                              m_aw_req.m_user  == '0;
                              m_aw_req.m_lock  == 1'b0;
                              m_aw_req.m_size  == 3'd3;
                              m_aw_req.m_burst == BurstFixed; }) begin
    `uvm_fatal(get_full_name(), "write_word: could not randomize the burst")
  end
  run_write(seq, "write_word");
endtask : write_word

task axi_sram_base_vseq::write_cap(bit [31:0] id, bit [63:0] addr,
                                   bit [63:0] lower, bit [63:0] upper, bit tag);
  axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wc");
  seq.m_data_items.push_back(make_wd(lower, 8'hFF, tag, 1'b0));
  seq.m_data_items.push_back(make_wd(upper, 8'hFF, tag, 1'b1));
  if (!seq.randomize() with { m_aw_req.m_id    == id;
                              m_aw_req.m_addr  == local::addr;
                              m_aw_req.m_user  == '0;
                              m_aw_req.m_lock  == 1'b0;
                              m_aw_req.m_size  == 3'd3;
                              m_aw_req.m_burst == BurstIncr; }) begin
    `uvm_fatal(get_full_name(), "write_cap: could not randomize the burst")
  end
  run_write(seq, "write_cap");
endtask : write_cap

task axi_sram_base_vseq::read_word(bit [31:0] id, bit [63:0] addr);
  axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rw");
  if (!seq.randomize() with { m_ar_req.m_id    == id;
                              m_ar_req.m_addr  == local::addr;
                              m_ar_req.m_user  == '0;
                              m_ar_req.m_lock  == 1'b0;
                              m_ar_req.m_size  == 3'd3;
                              m_ar_req.m_len   == 8'd0;
                              m_ar_req.m_burst == BurstFixed; }) begin
    `uvm_fatal(get_full_name(), "read_word: could not randomize the burst")
  end
  run_read(seq, "read_word", 1);
endtask : read_word

task axi_sram_base_vseq::read_cap(bit [31:0] id, bit [63:0] addr);
  axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rc");
  if (!seq.randomize() with { m_ar_req.m_id    == id;
                              m_ar_req.m_addr  == local::addr;
                              m_ar_req.m_user  == '0;
                              m_ar_req.m_lock  == 1'b0;
                              m_ar_req.m_size  == 3'd3;
                              m_ar_req.m_len   == 8'd1;
                              m_ar_req.m_burst == BurstIncr; }) begin
    `uvm_fatal(get_full_name(), "read_cap: could not randomize the burst")
  end
  run_read(seq, "read_cap", 2);
endtask : read_cap
