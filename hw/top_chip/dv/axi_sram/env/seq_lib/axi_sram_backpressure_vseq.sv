// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // backpressure -- the manager throttles B and R, so the DUT's internal buffers fill and it has to
  // deassert its own ready signals. Data and CHERI tag must survive.
  //
  // Each accept is given a low random duty cycle for READY ahead of VALID and a random delay
  // after it, drawn per transaction so the throttling varies across the run. The delay is pinned,
  // which overrides the soft constraint that normally keeps it short.
  //
  // The request channels are not paced: the manager's AW/W/AR drivers assert VALID as soon as an
  // item is available and the agent exposes no delay for them. Backpressure here is therefore
  // response-side only.
  class axi_sram_backpressure_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_backpressure_vseq)
    function new(string name = "axi_sram_backpressure_vseq"); super.new(name); endfunction

    // Cycles to hold READY off after VALID. Never zero, so every response is throttled, and the
    // top of the range is well past the DUT's buffering.
    localparam int unsigned MinReadyDelay = 4;
    localparam int unsigned MaxReadyDelay = 12;
    // READY may lead VALID, but only on a small fraction of cycles.
    localparam int unsigned MaxReadyPct   = 10;

    // Pin a B accept to a throttled timing drawn for this transaction.
    protected function automatic void throttle_b(axi_mgr_write_burst_vseq seq);
      seq.m_b_accept.m_use_fixed_ready_without_valid_pct = 1'b1;
      seq.m_b_accept.m_fixed_ready_without_valid_pct     = $urandom_range(0, MaxReadyPct);
      seq.m_b_accept.m_use_fixed_valid_to_ready_delay    = 1'b1;
      seq.m_b_accept.m_fixed_valid_to_ready_delay        = $urandom_range(MinReadyDelay,
                                                                          MaxReadyDelay);
    endfunction

    // Pin an R accept to a throttled timing drawn for this transaction.
    protected function automatic void throttle_r(axi_mgr_read_burst_vseq seq);
      seq.m_r_accept.m_use_fixed_ready_without_valid_pct = 1'b1;
      seq.m_r_accept.m_fixed_ready_without_valid_pct     = $urandom_range(0, MaxReadyPct);
      seq.m_r_accept.m_use_fixed_valid_to_ready_delay    = 1'b1;
      seq.m_r_accept.m_fixed_valid_to_ready_delay        = $urandom_range(MinReadyDelay,
                                                                          MaxReadyDelay);
    endfunction

    task body();
      localparam int unsigned   NumWords = 8;
      localparam bit [63:0]     Base     = 64'h0000_2000;
      localparam bit [63:0]     CapAddr  = 64'h0000_2100;
      axi_mgr_write_burst_vseq  wseq;
      axi_mgr_read_burst_vseq   rseq;
      bit [63:0]                exp[NumWords];
      await_reset();

      // Throttled single-beat writes, back to back so the write path stays loaded.
      for (int unsigned i = 0; i < NumWords; i++) begin
        exp[i] = 64'h5A5A_0000_0000_0000 + (i << 8) + i;
        wseq = axi_mgr_write_burst_vseq::type_id::create($sformatf("bp_w%0d", i));
        wseq.m_data_items.push_back(make_wd(exp[i], 8'hFF, 1'b0, 1'b1));
        if (!wseq.randomize() with { m_aw_req.m_id    == 32'd3;
                                     m_aw_req.m_addr  == Base + 8 * local::i;
                                     m_aw_req.m_user  == '0;
                                     m_aw_req.m_size  == 3'd3;
                                     m_aw_req.m_burst == BurstFixed; })
          `uvm_fatal(get_full_name(), "backpressure: could not randomize the write")
        throttle_b(wseq);
        run_write(wseq, $sformatf("backpressure write %0d", i));
      end

      // A throttled capability write, so the tag path is loaded the same way.
      wseq = axi_mgr_write_burst_vseq::type_id::create("bp_cap");
      wseq.m_data_items.push_back(make_wd(64'hC0FF_EE00_0000_0001, 8'hFF, 1'b1, 1'b0));
      wseq.m_data_items.push_back(make_wd(64'hC0FF_EE00_0000_0002, 8'hFF, 1'b1, 1'b1));
      if (!wseq.randomize() with { m_aw_req.m_id    == 32'd4;
                                   m_aw_req.m_addr  == CapAddr;
                                   m_aw_req.m_user  == '0;
                                   m_aw_req.m_size  == 3'd3;
                                   m_aw_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "backpressure: could not randomize the capability write")
      throttle_b(wseq);
      run_write(wseq, "backpressure capability write");

      // Read it all back, still throttled.
      for (int unsigned i = 0; i < NumWords; i++) begin
        rseq = axi_mgr_read_burst_vseq::type_id::create($sformatf("bp_r%0d", i));
        if (!rseq.randomize() with { m_ar_req.m_id    == 32'd3;
                                     m_ar_req.m_addr  == Base + 8 * local::i;
                                     m_ar_req.m_user  == '0;
                                     m_ar_req.m_size  == 3'd3;
                                     m_ar_req.m_len   == 8'd0;
                                     m_ar_req.m_burst == BurstFixed; })
          `uvm_fatal(get_full_name(), "backpressure: could not randomize the read")
        throttle_r(rseq);
        run_read(rseq, $sformatf("backpressure read %0d", i), 1);
        if (rseq.m_read_beats[0].m_data[63:0] != exp[i])
          `uvm_error(get_full_name(), $sformatf(
                     "backpressure data @0x%0h: got 0x%016h, expected 0x%016h",
                     Base + 8 * i, rseq.m_read_beats[0].m_data[63:0], exp[i]))
      end

      rseq = axi_mgr_read_burst_vseq::type_id::create("bp_rcap");
      if (!rseq.randomize() with { m_ar_req.m_id    == 32'd4;
                                   m_ar_req.m_addr  == CapAddr;
                                   m_ar_req.m_user  == '0;
                                   m_ar_req.m_size  == 3'd3;
                                   m_ar_req.m_len   == 8'd1;
                                   m_ar_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "backpressure: could not randomize the capability read")
      throttle_r(rseq);
      run_read(rseq, "backpressure capability read", 2);
      if (rseq.m_read_beats[0].m_user[0] != 1 || rseq.m_read_beats[1].m_user[0] != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "backpressure lost the tag: ruser=%0b%0b",
                   rseq.m_read_beats[1].m_user[0], rseq.m_read_beats[0].m_user[0]))
    endtask
  endclass
