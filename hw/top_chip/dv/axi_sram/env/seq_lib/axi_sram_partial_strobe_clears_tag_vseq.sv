// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // partial_strobe_clears_tag -- a sub-64-bit (partial write-strobe) write to a
  // tagged slot clears the tag (size<3 -> is_w_cap_sized false -> tag written 0).
  class axi_sram_partial_strobe_clears_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_partial_strobe_clears_tag_vseq)
    function new(string name = "axi_sram_partial_strobe_clears_tag_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0060;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      await_reset();
      write_cap(32'd14, addr, 64'h1111_1111_1111_1111, 64'h2222_2222_2222_2222, 1'b1);
      read_cap(32'd14, addr, lo, hi, u0, u1);
      if (u0 != 1) `uvm_error(get_full_name(), "precondition: tag must be set")

      // size=2 (4-byte transfer) -> wstrb=0x0F, a partial strobe.
      write_word_strb(32'd14, addr, 64'h0000_0000_DEAD_BEEF, 3'd2, 8'h0F);
      read_cap(32'd14, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "partial_strobe_clears_tag: tag not cleared (ruser=%0b%0b)", u1, u0))
    endtask
  endclass
