// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // subword_read_clears_tag -- a sub-word read (size<3) of a valid cap region
  // returns data but with the tag cleared; the stored tag is unchanged.
  class axi_sram_subword_read_clears_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_subword_read_clears_tag_vseq)
    function new(string name = "axi_sram_subword_read_clears_tag_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0700;   // 16-byte aligned
      bit [63:0] lo, hi;
      bit        u0, u1;
      bit [63:0] data[$];
      bit        ruser[$];
      await_reset();
      write_cap(32'd15, addr, 64'h7777_7777_7777_7777, 64'h8888_8888_8888_8888, 1'b1);
      read_cap(32'd15, addr, lo, hi, u0, u1);
      if (u0 != 1) `uvm_error(get_full_name(), "precondition: stored cap must be valid")

      // Sub-word read (size=2): returned tag must be cleared.
      read_generic(32'd15, addr, 1, 3'd2, 3'd0, data, ruser);
      if (ruser[0] != 0)
        `uvm_error(get_full_name(), $sformatf("subword read returned tag=%0b (expect 0)", ruser[0]))

      // The stored capability itself is unaffected -- a full cap read still sees tag=1.
      read_cap(32'd15, addr, lo, hi, u0, u1);
      if (u0 != 1)
        `uvm_error(get_full_name(), "stored tag must be unchanged by a sub-word read")
    endtask
  endclass
