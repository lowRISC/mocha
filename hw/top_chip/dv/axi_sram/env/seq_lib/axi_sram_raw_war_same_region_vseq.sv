// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // raw_war_same_region -- a read and a write to one region issued together, both orders, data and
  // tag.
  //
  // axi_to_detailed_mem holds one burst per direction and interleaves their beats on a single
  // memory port, so either access can be served first. The scoreboard checks each read against the
  // writes that completed before it.
  class axi_sram_raw_war_same_region_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_raw_war_same_region_vseq)

    function new(string name = "axi_sram_raw_war_same_region_vseq");
      super.new(name);
    endfunction

    task body();
      localparam bit [63:0] Addr    = 64'h0000_6000;
      localparam bit [63:0] CapAddr = 64'h0000_6100;
      localparam bit [63:0] Old     = 64'h0F0F_0F0F_0F0F_0F0F;
      localparam bit [63:0] New     = 64'hF0F0_F0F0_F0F0_F0F0;
      await_reset();

      // RAW: the region holds Old, a write of New races a read.
      write_word(32'd16, Addr, Old);
      fork
        write_word(32'd17, Addr, New);
        read_word (32'd18, Addr);
      join
      read_word(32'd16, Addr);

      // WAR: the read is issued first and the write lands underneath it.
      fork
        read_word (32'd19, Addr);
        write_word(32'd20, Addr, Old);
      join
      read_word(32'd16, Addr);

      // The tag path races the same way: a capability write against a read of its region.
      write_word(32'd21, CapAddr, 64'h0);
      fork
        write_cap(32'd22, CapAddr, 64'hCAFE_0001_CAFE_0001, 64'hCAFE_0002_CAFE_0002, 1'b1);
        read_cap (32'd23, CapAddr);
      join
      read_cap(32'd16, CapAddr);
    endtask
  endclass
