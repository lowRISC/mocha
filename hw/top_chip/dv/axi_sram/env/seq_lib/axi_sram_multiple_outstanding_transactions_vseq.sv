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

      await_reset();

      for (int i = 0; i < NumWords; i++) begin
        write_word(32'(i + 10), Base + 8 * i, 64'h1234_0000_0000_0000 + (i << 16) + i);
      end
      write_cap(32'd20, CapA, 64'hAAAA_0001_AAAA_0001, 64'hAAAA_0002_AAAA_0002, 1'b1);
      write_cap(32'd21, CapB, 64'hBBBB_0001_BBBB_0001, 64'hBBBB_0002_BBBB_0002, 1'b1);

      // All eight reads in flight at once, each on its own ID.
      fork
        begin read_word(32'd10, Base + 8 * 0); end
        begin read_word(32'd11, Base + 8 * 1); end
        begin read_word(32'd12, Base + 8 * 2); end
        begin read_word(32'd13, Base + 8 * 3); end
        begin read_word(32'd14, Base + 8 * 4); end
        begin read_word(32'd15, Base + 8 * 5); end
        begin read_cap (32'd20, CapA); end
        begin read_cap (32'd21, CapB); end
      join
    endtask
  endclass
