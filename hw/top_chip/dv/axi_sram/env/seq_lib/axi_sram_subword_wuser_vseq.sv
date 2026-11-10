// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // subword_wuser -- a sub-word write with WUSER=1 to a tagged slot only partly writes it, so it
  // clears the tag like any other partial write.
  class axi_sram_subword_wuser_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_subword_wuser_vseq)

    function new(string name = "axi_sram_subword_wuser_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0B00;   // 16-byte aligned
      await_reset();
      write_cap(32'd25, addr, 64'h1111_1111_1111_1111, 64'h2222_2222_2222_2222, 1'b1);
      // size=2 (4-byte transfer) -> wstrb=0x0F, with WUSER set.
      write_word_strb(32'd25, addr, 64'h0000_0000_DEAD_BEEF, 3'd2, 8'h0F, 1'b1);
      read_cap(32'd25, addr);
    endtask
  endclass
