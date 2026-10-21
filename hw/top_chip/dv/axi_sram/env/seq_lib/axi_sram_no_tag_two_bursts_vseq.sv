// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // no_tag_two_bursts -- covering a 128-bit region with two SEPARATE single-beat
  // wuser=1 writes must NOT set the tag (it needs one 2-beat capability burst).
  class axi_sram_no_tag_two_bursts_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_no_tag_two_bursts_vseq)
    function new(string name = "axi_sram_no_tag_two_bursts_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_00D0;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      await_reset();
      // Two independent single-beat writes, each asserting wuser=1.
      write_word_user(32'd12, addr,     64'hCAFE_0000_0000_0001, 1'b1);
      write_word_user(32'd12, addr + 8, 64'hCAFE_0000_0000_0002, 1'b1);
      read_cap(32'd12, addr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "no_tag_two_bursts: tag set without a single cap burst (ruser=%0b%0b)", u1, u0))
    endtask
  endclass
