// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Behavioural shadow of the SRAM (data + CHERI tags). Driven by observed writes,
  // queried to predict read-backs. Tag rule: a region's tag is set only by a full
  // capability write (awlen==1, awsize==3, 16B-aligned, full strobes, both beats
  // agreeing on wuser); any other write clears it. A read returns the tag only when it
  // is capability-shaped and aligned (arlen==1, arsize==3, 16B-aligned), else 0. Data is
  // byte-addressed; unwritten bytes read 0 (matching the TB's power-up RAM zeroing).
  class axi_sram_ref_model extends uvm_object;
    `uvm_object_utils(axi_sram_ref_model)

    protected bit [7:0] m_data [bit [63:0]];   // byte address -> byte
    protected bit       m_tag  [bit [63:0]];   // 16-byte region base -> tag

    function new(string name = "axi_sram_ref_model");
      super.new(name);
    endfunction

    protected function automatic bit [63:0] region_base(bit [63:0] addr);
      return addr & ~64'hF;
    endfunction

    // Address of beat `i` of a burst. The DUT does not look at AxBURST at all: axi_to_detailed_mem
    // increments by the beat size on every beat whatever the burst type, and its own assertion
    // rejects a multi-beat non-INCR burst. The FIXED case below therefore only matches the DUT
    // for the single-beat FIXED bursts the tests issue, which is all that reaches it.
    function automatic bit [63:0] beat_addr(bit [63:0] base, bit [2:0] size,
                                            bit [1:0] burst, int i);
      if (burst == 2'b00) return base;                 // FIXED
      return base + (64'(i) * (64'd1 << size));        // INCR
    endfunction

    // Apply an observed full write transaction.
    function void predict_write(axi_mon_write_item tr);
      int        nbeats   = int'(tr.m_awlen) + 1;
      bit [63:0] base     = tr.m_awaddr;
      bit        cap_user = tr.m_wuser[0][0];
      bit        full_cap = (tr.m_awlen == 8'd1) && (tr.m_awsize == 3'd3) && (base[3:0] == 4'd0);

      foreach (tr.m_wstrb[i]) if (tr.m_wstrb[i][7:0] !== 8'hFF)    full_cap = 1'b0;
      foreach (tr.m_wuser[i]) if (tr.m_wuser[i][0]   !== cap_user) full_cap = 1'b0;

      // Data: commit each enabled byte lane to its byte address.
      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(base, tr.m_awsize, tr.m_awburst, i);
        bit [63:0] wbase = baddr & ~64'h7;             // 8-byte bus-word base
        for (int lane = 0; lane < 8; lane++)
          if (tr.m_wstrb[i][lane]) m_data[wbase + lane] = tr.m_wdata[i][8*lane +: 8];
      end

      // Tag: set only for a full capability write, else clear every touched region.
      if (full_cap) begin
        m_tag[region_base(base)] = cap_user;
      end else begin
        for (int i = 0; i < nbeats; i++)
          m_tag[region_base(beat_addr(base, tr.m_awsize, tr.m_awburst, i))] = 1'b0;
      end
    endfunction

    // Expected 8-byte read-back for the word containing `word_base`.
    function automatic bit [63:0] expected_word(bit [63:0] word_base);
      expected_word = '0;
      for (int lane = 0; lane < 8; lane++)
        if (m_data.exists(word_base + lane))
          expected_word[8*lane +: 8] = m_data[word_base + lane];
    endfunction

    // Predict the per-beat data and RUSER (tag) of an observed read transaction.
    function void predict_read(axi_mon_read_item tr, output bit [63:0] exp_data[$],
                                                output bit        exp_user[$]);
      int  nbeats   = int'(tr.m_arlen) + 1;
      // Capability-shaped and 16-byte aligned. The alignment matters: the DUT's
      // is_r_cap_aligned wants araddr[3:0]==0 on the first beat and ==8 on the second, so a
      // 2-beat burst that starts mid-region returns a cleared tag on both beats.
      bit  cap_read = (tr.m_arlen == 8'd1) && (tr.m_arsize == 3'd3) &&
                      (tr.m_araddr[3:0] == 4'd0);
      exp_data.delete();
      exp_user.delete();
      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(tr.m_araddr, tr.m_arsize, tr.m_arburst, i);
        bit [63:0] reg_b = region_base(baddr);
        exp_data.push_back(expected_word(baddr & ~64'h7));
        exp_user.push_back((cap_read && m_tag.exists(reg_b)) ? m_tag[reg_b] : 1'b0);
      end
    endfunction
  endclass
