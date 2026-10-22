// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // waw_same_address -- back-to-back writes to one address must leave the last write's data and
  // tag. Checked for data over a plain word, and for the tag in both directions: a capability
  // overwritten by plain data loses the tag, and plain data overwritten by a capability gains it.
  class axi_sram_waw_same_address_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_waw_same_address_vseq)
    function new(string name = "axi_sram_waw_same_address_vseq"); super.new(name); endfunction

    task body();
      localparam bit [63:0] WordAddr = 64'h0000_5000;
      localparam bit [63:0] CapAddr  = 64'h0000_5100;
      bit [63:0] rdata, lo, hi;
      bit        u0, u1;
      await_reset();

      // Data: three writes to one address, last one wins.
      write_word(32'd24, WordAddr, 64'h1111_1111_1111_1111);
      write_word(32'd24, WordAddr, 64'h2222_2222_2222_2222);
      write_word(32'd24, WordAddr, 64'h3333_3333_3333_3333);
      read_word(32'd24, WordAddr, rdata);
      if (rdata != 64'h3333_3333_3333_3333)
        `uvm_error(get_full_name(), $sformatf("waw data: got 0x%016h, expected the last write",
                                             rdata))

      // Tag set then cleared: a capability followed by a plain write over the same slot.
      write_cap (32'd25, CapAddr, 64'hC0DE_0001_C0DE_0001, 64'hC0DE_0002_C0DE_0002, 1'b1);
      write_word(32'd25, CapAddr, 64'hDEAD_DEAD_DEAD_DEAD);
      read_cap(32'd25, CapAddr, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "waw tag: plain write over a capability left ruser=%0b%0b", u1, u0))
      if (lo != 64'hDEAD_DEAD_DEAD_DEAD)
        `uvm_error(get_full_name(), $sformatf("waw tag: lower word is 0x%016h", lo))

      // Tag cleared then set: the capability write after it must take effect.
      write_cap(32'd26, CapAddr, 64'hFEED_0001_FEED_0001, 64'hFEED_0002_FEED_0002, 1'b1);
      read_cap(32'd26, CapAddr, lo, hi, u0, u1);
      if (lo != 64'hFEED_0001_FEED_0001 || hi != 64'hFEED_0002_FEED_0002 || u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "waw tag: capability over plain data gave lo=0x%016h hi=0x%016h u=%0b%0b",
                   lo, hi, u1, u0))
    endtask
  endclass
