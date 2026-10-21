// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // multiple_outstanding_transactions -- reads and writes to distinct addresses issued together
  // must all complete with the right data and tag, each response on its request's ID.
  //
  // Nothing is ever actually outstanding together: axi_to_detailed_mem accepts one burst per
  // direction, so it back-pressures ARREADY until the burst in progress is done. The requests are
  // still issued concurrently on distinct IDs, which is as far as this DUT can be pushed.
  class axi_sram_multiple_outstanding_transactions_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_multiple_outstanding_transactions_vseq)
    function new(string name = "axi_sram_multiple_outstanding_transactions_vseq");
      super.new(name);
    endfunction

    task body();
      localparam int unsigned NumWords = 6;
      localparam bit [63:0]   Base     = 64'h0000_4000;
      localparam bit [63:0]   CapA     = 64'h0000_4200;
      localparam bit [63:0]   CapB     = 64'h0000_4300;
      bit [63:0] exp[NumWords];
      bit [63:0] got[NumWords];
      bit [63:0] la, ha, lb, hb;
      bit        ua0, ua1, ub0, ub1;

      // Every response must come back on its request's ID.
      m_check_resp_id = 1'b1;
      await_reset();

      foreach (exp[i]) begin
        exp[i] = 64'h1234_0000_0000_0000 + (i << 16) + i;
        write_word(32'(i + 10), Base + 8 * i, exp[i]);
      end
      write_cap(32'd20, CapA, 64'hAAAA_0001_AAAA_0001, 64'hAAAA_0002_AAAA_0002, 1'b1);
      write_cap(32'd21, CapB, 64'hBBBB_0001_BBBB_0001, 64'hBBBB_0002_BBBB_0002, 1'b1);

      // All eight reads in flight at once, each on its own ID.
      fork
        begin read_word(32'd10, Base + 8 * 0, got[0]); end
        begin read_word(32'd11, Base + 8 * 1, got[1]); end
        begin read_word(32'd12, Base + 8 * 2, got[2]); end
        begin read_word(32'd13, Base + 8 * 3, got[3]); end
        begin read_word(32'd14, Base + 8 * 4, got[4]); end
        begin read_word(32'd15, Base + 8 * 5, got[5]); end
        begin read_cap (32'd20, CapA, la, ha, ua0, ua1); end
        begin read_cap (32'd21, CapB, lb, hb, ub0, ub1); end
      join

      foreach (exp[i]) begin
        if (got[i] != exp[i])
          `uvm_error(get_full_name(), $sformatf(
                     "outstanding read @0x%0h: got 0x%016h, expected 0x%016h",
                     Base + 8 * i, got[i], exp[i]))
      end
      if (la != 64'hAAAA_0001_AAAA_0001 || ha != 64'hAAAA_0002_AAAA_0002 || ua0 != 1 || ua1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "outstanding capability A: lo=0x%016h hi=0x%016h u=%0b%0b", la, ha, ua1, ua0))
      if (lb != 64'hBBBB_0001_BBBB_0001 || hb != 64'hBBBB_0002_BBBB_0002 || ub0 != 1 || ub1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "outstanding capability B: lo=0x%016h hi=0x%016h u=%0b%0b", lb, hb, ub1, ub0))
    endtask
  endclass
