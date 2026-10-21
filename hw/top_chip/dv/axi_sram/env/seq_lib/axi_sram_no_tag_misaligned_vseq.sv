// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // no_tag_misaligned -- a 2-beat wuser=1 burst starting at a non-16-byte-aligned
  // address must NOT set the tag (is_w_cap_aligned requires addr[3:0]==0).
  class axi_sram_no_tag_misaligned_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_no_tag_misaligned_vseq)
    function new(string name = "axi_sram_no_tag_misaligned_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr  = 64'h0000_0048;   // addr[3:0]=8 -> misaligned for a capability
      bit [63:0] lower = 64'h1234_5678_9ABC_DEF0;
      bit [63:0] upper = 64'hFEDC_BA98_7654_3210;
      bit [63:0] rl, ru, dummy_lo, dummy_hi;
      bit        u0, u1;
      await_reset();
      // 2-beat cap-shaped write at the misaligned address with wuser=1.
      write_cap(32'd11, addr, lower, upper, 1'b1);
      // Data must still be written.
      read_word(32'd11, addr,     rl);
      read_word(32'd11, addr + 8, ru);
      if (rl != lower || ru != upper)
        `uvm_error(get_full_name(),
                   $sformatf("misaligned data lost: lo=0x%016h hi=0x%016h", rl, ru))
      // Tag bit for region 0x40: read the aligned capability slot and check it is clear.
      read_cap(32'd11, 64'h0000_0040, dummy_lo, dummy_hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "no_tag_misaligned: tag set by misaligned burst (ruser=%0b%0b)", u1, u0))
    endtask
  endclass
