// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Reference model of the SRAM data and CHERI tags, updated by observed writes and used to
  // predict reads. The tag rules follow the SRAM specification in doc/ref/arch.md.
  // Unwritten bytes read 0.
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

    // Address of beat i of a burst. A FIXED burst uses the start address for every beat, and any
    // other burst moves forward by the beat size on each beat.
    function automatic bit [63:0] beat_addr(bit [63:0] base, bit [2:0] size,
                                            bit [1:0] burst, int i);
      if (burst == 2'b00) return base;                 // FIXED
      return base + (64'(i) * (64'd1 << size));        // INCR
    endfunction

    // Apply an observed full write transaction.
    function void predict_write(axi_mon_write_item tr);
      int        nbeats = int'(tr.m_awlen) + 1;
      bit [63:0] base   = tr.m_awaddr;
      // Per slot, which 64-bit halves this burst wrote in full, and the WUSER each carried.
      bit [1:0]  whole [bit [63:0]];
      bit [1:0]  user  [bit [63:0]];

      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(base, tr.m_awsize, tr.m_awburst, i);
        bit [63:0] wbase = baddr & ~64'h7;             // 8-byte bus-word base
        bit [63:0] slot  = region_base(baddr);

        // Data: commit each enabled byte lane to its byte address.
        for (int lane = 0; lane < 8; lane++)
          if (tr.m_wstrb[i][lane]) m_data[wbase + lane] = tr.m_wdata[i][8*lane +: 8];

        if (!whole.exists(slot)) begin
          whole[slot] = '0;
          user[slot]  = '0;
        end
        if (tr.m_awsize == 3'd3 && tr.m_wstrb[i][7:0] === 8'hFF) begin
          whole[slot][baddr[3]] = 1'b1;
          user[slot][baddr[3]]  = tr.m_wuser[i][0];
        end
      end

      // Tag: set only when both halves of the slot were written in full with WUSER set to 1.
      // Any other write to the slot clears it.
      foreach (whole[slot]) m_tag[slot] = (whole[slot] == 2'b11) && (user[slot] == 2'b11);
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
      int       nbeats = int'(tr.m_arlen) + 1;
      // Per slot, which 64-bit halves this burst reads in full. A beat returns its slot's tag only
      // when the burst reads both halves, so a partial or sub-word read of a capability is untagged.
      bit [1:0] whole [bit [63:0]];

      if (tr.m_arsize == 3'd3) begin
        for (int i = 0; i < nbeats; i++) begin
          bit [63:0] baddr = beat_addr(tr.m_araddr, tr.m_arsize, tr.m_arburst, i);
          // A first beat that starts part way into its word reads only part of it.
          if (i == 0 && tr.m_araddr[2:0] != 3'd0) continue;
          if (!whole.exists(region_base(baddr))) whole[region_base(baddr)] = '0;
          whole[region_base(baddr)][baddr[3]] = 1'b1;
        end
      end

      exp_data.delete();
      exp_user.delete();
      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(tr.m_araddr, tr.m_arsize, tr.m_arburst, i);
        bit [63:0] slot  = region_base(baddr);
        exp_data.push_back(expected_word(baddr & ~64'h7));
        exp_user.push_back(whole.exists(slot) && whole[slot] == 2'b11 && m_tag.exists(slot) ?
                           m_tag[slot] : 1'b0);
      end
    endfunction
  endclass
