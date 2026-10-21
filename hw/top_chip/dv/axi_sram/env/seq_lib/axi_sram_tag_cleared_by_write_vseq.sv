// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // tag_cleared_by_write -- a plain data write to a tagged slot clears the tag.
  class axi_sram_tag_cleared_by_write_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_cleared_by_write_vseq)

    function new(string name = "axi_sram_tag_cleared_by_write_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0050;   // 16-byte aligned
      await_reset();
      // Store a tagged capability.
      write_cap(32'd7, addr, 64'hAAAA_AAAA_AAAA_AAAA, 64'hBBBB_BBBB_BBBB_BBBB, 1'b1);
      read_cap(32'd7, addr);

      // Plain write to the lower word clears the whole region's tag.
      write_word(32'd7, addr, 64'h1234_5678_9ABC_DEF0);
      read_cap(32'd7, addr);

      // Upper word must be untouched.
      read_word(32'd7, addr + 8);
    endtask
  endclass
