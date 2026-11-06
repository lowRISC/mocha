// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // raw_war_same_region -- a read and a write to one region issued together, both orders, data and
  // tag.
  //
  // No hazard arises: axi_to_detailed_mem accepts one burst per direction and arbitrates both onto
  // a single memory port, so it holds ARREADY low until the write has been serviced. The accesses
  // therefore complete in issue order and the read returns the value the write left. The test
  // still accepts either value, so it keeps working if the bridge ever pipelines.
  class axi_sram_raw_war_same_region_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_raw_war_same_region_vseq)
    function new(string name = "axi_sram_raw_war_same_region_vseq"); super.new(name); endfunction

    task body();
      localparam bit [63:0] Addr    = 64'h0000_6000;
      localparam bit [63:0] CapAddr = 64'h0000_6100;
      localparam bit [63:0] Old     = 64'h0F0F_0F0F_0F0F_0F0F;
      localparam bit [63:0] New     = 64'hF0F0_F0F0_F0F0_F0F0;
      bit [63:0] raced, rdata, lo, hi;
      bit        u0, u1;
      await_reset();

      // RAW: the region holds Old, a write of New races a read.
      write_word(32'd16, Addr, Old);
      fork
        write_word(32'd17, Addr, New);
        read_word (32'd18, Addr, raced);
      join
      if (raced != Old && raced != New)
        `uvm_error(get_full_name(), $sformatf(
                   "RAW read returned 0x%016h, neither the old nor the new value", raced))

      read_word(32'd16, Addr, rdata);
      if (rdata != New)
        `uvm_error(get_full_name(), $sformatf("after the RAW race the region holds 0x%016h",
                                              rdata))

      // WAR: the read is issued first and the write lands underneath it.
      fork
        read_word (32'd19, Addr, raced);
        write_word(32'd20, Addr, Old);
      join
      if (raced != Old && raced != New)
        `uvm_error(get_full_name(), $sformatf(
                   "WAR read returned 0x%016h, neither the old nor the new value", raced))

      read_word(32'd16, Addr, rdata);
      if (rdata != Old)
        `uvm_error(get_full_name(), $sformatf("after the WAR race the region holds 0x%016h",
                                              rdata))

      // The tag path races the same way: a capability write against a read of its region.
      write_word(32'd21, CapAddr, 64'h0);
      fork
        write_cap(32'd22, CapAddr, 64'hCAFE_0001_CAFE_0001, 64'hCAFE_0002_CAFE_0002, 1'b1);
        read_cap (32'd23, CapAddr, lo, hi, u0, u1);
      join
      // Nothing holds on the racing read itself, not even that its two beats agree: they are
      // separate memory accesses, so a tag write can land between them.

      read_cap(32'd16, CapAddr, lo, hi, u0, u1);
      if (lo != 64'hCAFE_0001_CAFE_0001 || hi != 64'hCAFE_0002_CAFE_0002 || u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "after the tag race the region holds lo=0x%016h hi=0x%016h u=%0b%0b",
                   lo, hi, u1, u0))
    endtask
  endclass
