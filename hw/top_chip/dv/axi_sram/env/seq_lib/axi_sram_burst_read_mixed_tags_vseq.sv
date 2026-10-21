// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // burst_read_mixed_tags -- a burst across a tagged and an untagged slot returns each slot's own
  // tag on that slot's beats. The scoreboard checks every beat against the model.
  class axi_sram_burst_read_mixed_tags_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_read_mixed_tags_vseq)

    function new(string name = "axi_sram_burst_read_mixed_tags_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] cap_addr   = 64'h0000_0080;   // tagged
      bit [63:0] plain_addr = 64'h0000_0090;   // untagged
      await_reset();
      write_cap(32'd7, cap_addr,   64'hCAFE_BABE_FEED_FACE, 64'hDEAD_BEEF_1234_5678, 1'b1);
      write_cap(32'd7, plain_addr, 64'hAAAA_AAAA_AAAA_AAAA, 64'hBBBB_BBBB_BBBB_BBBB, 1'b0);

      read_cap(32'd7, cap_addr);
      read_cap(32'd7, plain_addr);

      // 4-beat burst across both slots: the first two beats are tagged, the last two are not.
      read_generic(32'd7, cap_addr, 4, 3'd3, 3'd0);
    endtask
  endclass
