// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // waw_same_address -- back-to-back writes to one address must leave the last write's data and
  // tag. Checked for data over a plain word, and for the tag in both directions: a capability
  // overwritten by plain data loses the tag, and plain data overwritten by a capability gains it.
  class axi_sram_waw_same_address_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_waw_same_address_vseq)

    function new(string name = "axi_sram_waw_same_address_vseq");
      super.new(name);
    endfunction

    task body();
      localparam bit [63:0] WordAddr = 64'h0000_5000;
      localparam bit [63:0] CapAddr  = 64'h0000_5100;
      await_reset();

      // Data: three writes to one address, last one wins.
      write_word(32'd24, WordAddr, 64'h1111_1111_1111_1111);
      write_word(32'd24, WordAddr, 64'h2222_2222_2222_2222);
      write_word(32'd24, WordAddr, 64'h3333_3333_3333_3333);
      read_word(32'd24, WordAddr);

      // Tag set then cleared: a capability followed by a plain write over the same slot.
      write_cap (32'd25, CapAddr, 64'hC0DE_0001_C0DE_0001, 64'hC0DE_0002_C0DE_0002, 1'b1);
      write_word(32'd25, CapAddr, 64'hDEAD_DEAD_DEAD_DEAD);
      read_cap(32'd25, CapAddr);

      // Tag cleared then set: the capability write after it must take effect.
      write_cap(32'd26, CapAddr, 64'hFEED_0001_FEED_0001, 64'hFEED_0002_FEED_0002, 1'b1);
      read_cap(32'd26, CapAddr);
    endtask
  endclass
