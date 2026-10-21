// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Reference model of the SRAM data and CHERI tags, updated by observed writes and used to
  // predict reads. The tag rules follow the SRAM specification in doc/ref/arch.md.
  // Bytes and tags that were never written are undefined, so they are left out of the prediction.
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
    // other burst moves forward by the beat size on each beat from the aligned start address.
    function automatic bit [63:0] beat_addr(bit [63:0] base, bit [2:0] size,
                                            bit [1:0] burst, int i);
      if (burst == 2'b00) begin
        return base;                                   // FIXED
      end
      if (i == 0) begin
        return base;
      end
      return (base & ~((64'd1 << size) - 1)) + (64'(i) * (64'd1 << size));   // INCR
    endfunction

    // Byte lanes a beat at addr carries data on: from addr up to the end of its size-aligned
    // container.
    function automatic bit [7:0] active_lanes(bit [63:0] addr, bit [2:0] size);
      int unsigned lo = addr[2:0];
      int unsigned hi = (addr[2:0] & ~((1 << size) - 1)) + (1 << size) - 1;
      for (int lane = 0; lane < 8; lane++) begin
        active_lanes[lane] = (lane >= lo) && (lane <= hi);
      end
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
        for (int lane = 0; lane < 8; lane++) begin
          if (tr.m_wstrb[i][lane]) begin
            m_data[wbase + lane] = tr.m_wdata[i][8*lane +: 8];
          end
        end

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
      foreach (whole[slot]) begin
        m_tag[slot] = (whole[slot] == 2'b11) && (user[slot] == 2'b11);
      end
    endfunction

    // Expected 8-byte read-back for the word containing `word_base`. known has a bit set for each
    // byte lane that was written.
    function automatic bit [63:0] expected_word(bit [63:0] word_base, output bit [7:0] known);
      expected_word = '0;
      known         = '0;
      for (int lane = 0; lane < 8; lane++) begin
        if (m_data.exists(word_base + lane)) begin
          expected_word[8*lane +: 8] = m_data[word_base + lane];
          known[lane]                = 1'b1;
        end
      end
    endfunction

    // Predict the per-beat data and RUSER (tag) of an observed read transaction. data_known gives
    // the byte lanes of each beat that carry data and were written, and user_known whether its tag
    // can be checked.
    function void predict_read(axi_mon_read_item tr, output bit [63:0] exp_data[$],
                                                output bit [7:0]  data_known[$],
                                                output bit        exp_user[$],
                                                output bit        user_known[$]);
      int       nbeats = int'(tr.m_arlen) + 1;
      // Per slot, which 64-bit halves this burst reads in full. A beat returns its slot's tag only
      // when the burst reads both halves, so a partial or sub-word read of a capability is untagged.
      bit [1:0] whole [bit [63:0]];

      if (tr.m_arsize == 3'd3) begin
        for (int i = 0; i < nbeats; i++) begin
          bit [63:0] baddr = beat_addr(tr.m_araddr, tr.m_arsize, tr.m_arburst, i);
          // A first beat that starts part way into its word reads only part of it.
          if (i == 0 && tr.m_araddr[2:0] != 3'd0) begin
            continue;
          end
          if (!whole.exists(region_base(baddr))) begin
            whole[region_base(baddr)] = '0;
          end
          whole[region_base(baddr)][baddr[3]] = 1'b1;
        end
      end

      exp_data.delete();
      data_known.delete();
      exp_user.delete();
      user_known.delete();
      for (int i = 0; i < nbeats; i++) begin
        bit [63:0] baddr = beat_addr(tr.m_araddr, tr.m_arsize, tr.m_arburst, i);
        bit [63:0] slot  = region_base(baddr);
        bit        cap   = whole.exists(slot) && whole[slot] == 2'b11;
        bit [7:0]  known;
        exp_data.push_back(expected_word(baddr & ~64'h7, known));
        data_known.push_back(known & active_lanes(baddr, tr.m_arsize));
        exp_user.push_back(cap && m_tag.exists(slot) ? m_tag[slot] : 1'b0);
        user_known.push_back(!cap || m_tag.exists(slot));
      end
    endfunction
  endclass
