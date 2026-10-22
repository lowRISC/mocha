// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // concurrent_data_tag -- a plain-data transaction and a capability transaction issued together
  // must both complete and read back correctly.
  //
  // The two writes go out sequentially: AXI4 forbids write-data interleaving, so two write
  // sequences sharing the W channel would have to be coordinated to keep W in AW order, which the
  // VIP does not do. The reads are issued together on distinct IDs, but they do not overlap on the
  // bus either: axi_to_detailed_mem accepts one read burst at a time.
  class axi_sram_concurrent_data_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_concurrent_data_tag_vseq)
    function new(string name = "axi_sram_concurrent_data_tag_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] data_addr = 64'h0000_0020;
      bit [63:0] cap_addr  = 64'h0000_0030;
      bit [63:0] data_val  = 64'hC0FFEE00_DEADC0DE;
      bit [63:0] cap_lo    = 64'hFEED_FACE_CAFE_BABE;
      bit [63:0] cap_hi    = 64'h0123_4567_89AB_CDEF;
      bit [63:0] rdata, rl, ru;
      bit        u0, u1;
      await_reset();

      // Writes (sequential -> compliant W ordering).
      write_word(32'd1, data_addr, data_val);
      write_cap (32'd2, cap_addr, cap_lo, cap_hi, 1'b1);

      // Reads in flight together (different IDs, routed by RID).
      fork
        read_word(32'd1, data_addr, rdata);
        read_cap (32'd2, cap_addr, rl, ru, u0, u1);
      join

      if (rdata != data_val)
        `uvm_error(get_full_name(), $sformatf("concurrent data mismatch: 0x%016h", rdata))
      if (rl != cap_lo || ru != cap_hi || u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "concurrent cap mismatch: lo=0x%016h hi=0x%016h u=%0b%0b", rl, ru, u1, u0))
      if (rdata == data_val && rl == cap_lo && ru == cap_hi && u0 == 1 && u1 == 1)
        `uvm_info(get_full_name(), "concurrent_data_tag: both transactions correct", UVM_LOW)
    endtask
  endclass
