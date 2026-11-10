// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // no_tag_single_beat -- WUSER=1 on a single-beat (awlen=0) write must NOT set
  // the region tag (is_w_cap_sized requires awlen=1).
  class axi_sram_no_tag_single_beat_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_no_tag_single_beat_vseq)

    function new(string name = "axi_sram_no_tag_single_beat_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0040;   // 16-byte aligned
      await_reset();
      // Single-beat write with WUSER=1 -- tag must stay 0.
      write_word_user(32'd6, addr, 64'h0BAD_0CAB_0BAD_0CAB, 1'b1);
      read_cap(32'd6, addr);
    endtask
  endclass
