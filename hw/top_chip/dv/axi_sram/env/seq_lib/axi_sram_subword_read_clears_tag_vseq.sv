// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // subword_read_clears_tag -- a sub-word read (size<3) of a valid cap region
  // returns data but with the tag cleared; the stored tag is unchanged.
  class axi_sram_subword_read_clears_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_subword_read_clears_tag_vseq)

    function new(string name = "axi_sram_subword_read_clears_tag_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0700;   // 16-byte aligned
      await_reset();
      write_cap(32'd15, addr, 64'h7777_7777_7777_7777, 64'h8888_8888_8888_8888, 1'b1);
      read_cap(32'd15, addr);

      // Sub-word reads (size=2) of one, two and four beats: returned tag must be cleared, even when
      // the beats cover the whole region.
      read_generic(32'd15, addr, 1, 3'd2, 3'd0);
      read_generic(32'd15, addr, 2, 3'd2, 3'd0);
      read_generic(32'd15, addr, 4, 3'd2, 3'd0);

      // The stored capability itself is unaffected -- a full cap read still sees tag=1.
      read_cap(32'd15, addr);
    endtask
  endclass
