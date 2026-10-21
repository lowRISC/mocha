// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // tag_write -- a full 128-bit aligned 2-beat burst with WUSER=1 sets the tag,
  // and data+tag are carried in the same transaction.
  class axi_sram_tag_write_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_write_vseq)

    function new(string name = "axi_sram_tag_write_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0010;
      await_reset();
      write_cap(32'd5, addr, 64'hAAAA_BBBB_CCCC_DDDD, 64'h1111_2222_3333_4444, 1'b1);
      read_cap(32'd5, addr);
    endtask
  endclass
