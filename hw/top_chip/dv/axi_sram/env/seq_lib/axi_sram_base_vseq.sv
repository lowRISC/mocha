// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Base virtual sequence -- runs on the virtual sequencer and provides the
  // read/write helper API (sequencers/routers/clk_rst sourced from p_sequencer).
  // Every per-test vseq extends this.
  class axi_sram_base_vseq extends uvm_sequence;
    `uvm_object_utils(axi_sram_base_vseq)
    `uvm_declare_p_sequencer(axi_sram_virtual_sequencer)

    // When set, run_write/run_read additionally assert response IDs track requests.
    protected bit m_check_resp_id = 1'b0;

    function new(string name = "axi_sram_base_vseq");
      super.new(name);
    endfunction

    // Apply a reset through the clk_rst_if, then wait for the agent's own reset to
    // stay deasserted. In the block tb the two are the same; a tb whose agent runs on
    // a derived reset that deasserts later or glitches would otherwise see a reset
    // mid-transaction.
    protected task automatic await_reset();
      int unsigned stable = 0;
      int unsigned waited = 0;
      p_sequencer.clk_rst_vif.apply_reset();
      while (stable < 20) begin
        p_sequencer.clk_rst_vif.wait_clks(1);
        waited++;
        if (waited > 10000) begin
          `uvm_fatal(get_full_name(), "DUT-side AXI reset (rst_ni) never stabilised high")
        end
        stable = (p_sequencer.agent_rst_vif.rst_n === 1'b1) ? (stable + 1) : 0;
      end
    endtask

    // Build a single write-data beat.
    protected function automatic axi_write_data_item make_wd(bit [63:0] data, bit [7:0] strb,
                                                             bit tag, bit last);
      axi_write_data_item it = axi_write_data_item::type_id::create("wd");
      it.m_data = 1024'(data);
      it.m_strb = 128'(strb);
      it.m_user = 512'(tag);
      it.m_last = last;
      return it;
    endfunction

    // Hand a write burst its channel sequencers and response router. Separate from run_write for
    // a test that has to start the burst itself.
    protected function automatic void wire_write(axi_mgr_write_burst_vseq seq);
      seq.set_write_response_router(p_sequencer.write_response_router);
      seq.set_sequencers(p_sequencer.write_request_seqr,
                         p_sequencer.write_data_seqr,
                         p_sequencer.write_response_seqr);
    endfunction

    // Drive a prepared write burst and check it gets OKAY.
    protected task automatic run_write(axi_mgr_write_burst_vseq seq, string ctx);
      // seq arrives fully randomised: the caller constrained the burst it wanted, so m_aw_req is
      // final here (AWLEN solved by len_matches_data_c).
      wire_write(seq);
      seq.start(null);
      if (seq.rsp == null || seq.rsp.m_write_response == null)
        `uvm_fatal(get_full_name(), {ctx, ": write completed with null B response (reset?)"})
      if (seq.rsp.m_write_response.m_resp != axi_write_response_item::BRespOkay)
        `uvm_error(get_full_name(), $sformatf("%s @0x%0h: non-OKAY BRESP %0d", ctx,
                   seq.m_aw_req.m_addr, seq.rsp.m_write_response.m_resp))
      if (m_check_resp_id && seq.rsp.m_write_response.m_id != seq.m_aw_req.m_id)
        `uvm_error(get_full_name(), $sformatf("%s: BID 0x%0h != AWID 0x%0h", ctx,
                   seq.rsp.m_write_response.m_id, seq.m_aw_req.m_id))
    endtask

    // Drive a prepared read burst, check the beat count and that every beat gets OKAY.
    protected task automatic run_read(axi_mgr_read_burst_vseq seq, string ctx,
                                      int unsigned exp_beats);
      seq.set_read_response_router(p_sequencer.read_response_router);
      seq.set_sequencers(p_sequencer.read_request_seqr, p_sequencer.read_data_seqr);
      seq.start(null);
      if (seq.m_read_beats.size() != exp_beats)
        `uvm_fatal(get_full_name(), $sformatf("%s: expected %0d beats, got %0d (reset?)",
                   ctx, exp_beats, seq.m_read_beats.size()))
      foreach (seq.m_read_beats[i]) begin
        if (seq.m_read_beats[i].m_resp != axi_read_data_item::RRespOkay)
          `uvm_error(get_full_name(), $sformatf("%s: beat %0d non-OKAY RRESP %0d", ctx, i,
                     seq.m_read_beats[i].m_resp))
        if (m_check_resp_id && seq.m_read_beats[i].m_id != seq.m_ar_req.m_id)
          `uvm_error(get_full_name(), $sformatf("%s: beat %0d RID 0x%0h != ARID 0x%0h", ctx, i,
                     seq.m_read_beats[i].m_id, seq.m_ar_req.m_id))
      end
    endtask

    // Single-beat 8-byte write (no CHERI tag).
    protected task automatic write_word(bit [31:0] id, bit [63:0] addr, bit [63:0] data);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("ww");
      // Beats first: len_matches_data_c ties AWLEN to m_data_items.size() during the solve.
      seq.m_data_items.push_back(make_wd(data, 8'hFF, 1'b0, 1'b1));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstFixed; })
        `uvm_fatal(get_full_name(), "write_word: could not randomize the burst")
      run_write(seq, "write_word");
    endtask

    // Single-beat 8-byte write asserting WUSER=tag (must NOT set the region tag).
    protected task automatic write_word_user(bit [31:0] id, bit [63:0] addr,
                                             bit [63:0] data, bit tag);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wwu");
      seq.m_data_items.push_back(make_wd(data, 8'hFF, tag, 1'b1));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstFixed; })
        `uvm_fatal(get_full_name(), "write_word_user: could not randomize the burst")
      run_write(seq, "write_word_user");
    endtask

    // 2-beat capability write (awlen=1, awsize=3, INCR) with WUSER=tag on both beats.
    protected task automatic write_cap(bit [31:0] id, bit [63:0] addr,
                                       bit [63:0] lower, bit [63:0] upper, bit tag);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wc");
      seq.m_data_items.push_back(make_wd(lower, 8'hFF, tag, 1'b0));
      seq.m_data_items.push_back(make_wd(upper, 8'hFF, tag, 1'b1));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "write_cap: could not randomize the burst")
      run_write(seq, "write_cap");
    endtask

    // N-beat data burst (awsize=3, INCR), no CHERI tag. words[i] is beat i.
    protected task automatic write_burst_words(bit [31:0] id, bit [63:0] addr,
                                               ref bit [63:0] words[$]);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wb");
      burst_e    bt       = (words.size() == 1) ? BurstFixed : BurstIncr;
      foreach (words[i])
        seq.m_data_items.push_back(make_wd(words[i], 8'hFF, 1'b0, 8'(i) == 8'(words.size() - 1)));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == bt; })
        `uvm_fatal(get_full_name(), "write_burst_words: could not randomize the burst")
      run_write(seq, "write_burst_words");
    endtask

    // Single-beat 8-byte read; returns data.
    protected task automatic read_word(bit [31:0] id, bit [63:0] addr, output bit [63:0] data);
      axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rw");
      if (!seq.randomize() with { m_ar_req.m_id    == id;
                                  m_ar_req.m_addr  == local::addr;
                                  m_ar_req.m_user  == '0;
                                  m_ar_req.m_size  == 3'd3;
                                  m_ar_req.m_len   == 8'd0;
                                  m_ar_req.m_burst == BurstFixed; })
        `uvm_fatal(get_full_name(), "read_word: could not randomize the burst")
      run_read(seq, "read_word", 1);
      data = seq.m_read_beats[0].m_data[63:0];
    endtask

    // 2-beat capability read (arlen=1, arsize=3, INCR). Returns data words + RUSER bits.
    protected task automatic read_cap(bit [31:0] id, bit [63:0] addr,
                                      output bit [63:0] lower, output bit [63:0] upper,
                                      output bit ruser0,      output bit ruser1);
      axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rc");
      if (!seq.randomize() with { m_ar_req.m_id    == id;
                                  m_ar_req.m_addr  == local::addr;
                                  m_ar_req.m_user  == '0;
                                  m_ar_req.m_size  == 3'd3;
                                  m_ar_req.m_len   == 8'd1;
                                  m_ar_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "read_cap: could not randomize the burst")
      run_read(seq, "read_cap", 2);
      lower  = seq.m_read_beats[0].m_data[63:0];
      upper  = seq.m_read_beats[1].m_data[63:0];
      ruser0 = seq.m_read_beats[0].m_user[0];
      ruser1 = seq.m_read_beats[1].m_user[0];
    endtask

    // Single-beat write with explicit AWSIZE/WSTRB (partial-strobe / sub-word).
    protected task automatic write_word_strb(bit [31:0] id, bit [63:0] addr, bit [63:0] data,
                                             bit [2:0] size, bit [7:0] strb);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wws");
      seq.m_data_items.push_back(make_wd(data, strb, 1'b0, 1'b1));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == size;
                                  m_aw_req.m_burst == BurstFixed; })
        `uvm_fatal(get_full_name(), "write_word_strb: could not randomize the burst")
      run_write(seq, "write_word_strb");
    endtask

    // 2-beat capability-shaped write with an independent WUSER per beat.
    protected task automatic write_cap_user(bit [31:0] id, bit [63:0] addr,
                                            bit [63:0] lower, bit [63:0] upper,
                                            bit user0, bit user1);
      axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("wcu");
      seq.m_data_items.push_back(make_wd(lower, 8'hFF, user0, 1'b0));
      seq.m_data_items.push_back(make_wd(upper, 8'hFF, user1, 1'b1));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "write_cap_user: could not randomize the burst")
      run_write(seq, "write_cap_user");
    endtask

    // General read burst: nbeats / AXI size / prot configurable. Returns each beat's
    // data word and per-beat RUSER bit.
    protected task automatic read_generic(bit [31:0] id, bit [63:0] addr, int unsigned nbeats,
                                          bit [2:0] size, bit [2:0] prot,
                                          ref bit [63:0] data[$], ref bit ruser[$]);
      axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("rg");
      burst_e    bt       = (nbeats == 1) ? BurstFixed : BurstIncr;
      if (!seq.randomize() with { m_ar_req.m_id    == id;
                                  m_ar_req.m_addr  == local::addr;
                                  m_ar_req.m_user  == '0;
                                  m_ar_req.m_size  == size;
                                  m_ar_req.m_len   == 8'(nbeats - 1);
                                  m_ar_req.m_burst == bt;
                                  m_ar_req.m_prot  == prot; })
        `uvm_fatal(get_full_name(), "read_generic: could not randomize the burst")
      run_read(seq, "read_generic", nbeats);
      data.delete();
      ruser.delete();
      foreach (seq.m_read_beats[i]) begin
        data.push_back(seq.m_read_beats[i].m_data[63:0]);
        ruser.push_back(seq.m_read_beats[i].m_user[0]);
      end
    endtask
  endclass
