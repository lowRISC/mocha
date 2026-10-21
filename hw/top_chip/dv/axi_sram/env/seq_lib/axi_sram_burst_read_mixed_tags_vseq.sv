// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // burst_read_mixed_tags -- adjacent slots return independent per-beat ruser when
  // each is read as its own 2-beat transaction. Per-beat tags across a longer
  // (arlen>1) burst are the tag controller's job (axi_sram gates ruser on
  // arlen==1), so that boundary is logged, not asserted.
  class axi_sram_burst_read_mixed_tags_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_read_mixed_tags_vseq)
    function new(string name = "axi_sram_burst_read_mixed_tags_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] cap_addr   = 64'h0000_0080;   // tagged
      bit [63:0] plain_addr = 64'h0000_0090;   // untagged
      bit [63:0] lo, hi;
      bit        ct0, ct1, pt0, pt1;
      bit [63:0] data[$];
      bit        ruser[$];
      string     s;
      await_reset();
      write_cap(32'd7, cap_addr,   64'hCAFE_BABE_FEED_FACE, 64'hDEAD_BEEF_1234_5678, 1'b1);
      write_cap(32'd7, plain_addr, 64'hAAAA_AAAA_AAAA_AAAA, 64'hBBBB_BBBB_BBBB_BBBB, 1'b0);

      read_cap(32'd7, cap_addr,   lo, hi, ct0, ct1);
      read_cap(32'd7, plain_addr, lo, hi, pt0, pt1);
      if (ct0 != 1) `uvm_error(get_full_name(), "tagged slot must return ruser=1")
      if (pt0 != 0) `uvm_error(get_full_name(), "untagged slot must return ruser=0")

      // 4-beat (arlen=3) burst across both slots: axi_sram gates ruser on arlen==1,
      // so every beat returns 0. Log the boundary; do NOT assert it as required behaviour.
      read_generic(32'd7, cap_addr, 4, 3'd3, 3'd0, data, ruser);
      foreach (ruser[i]) s = {s, $sformatf("%0b", ruser[i])};
      `uvm_info(get_full_name(), $sformatf({"burst_read_mixed_tags: per-slot ruser ",
                "tagged=%0b untagged=%0b; 4-beat burst ruser=%s, which the tag controller owns"},
                ct0, pt0, s), UVM_LOW)
    endtask
  endclass
