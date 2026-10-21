// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // cap_both_ruser_set -- both RUSER beats of a valid cap read are 1, both 0 for
  // an untagged region (the core ANDs the two beats to judge validity).
  class axi_sram_cap_ruser_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_cap_ruser_vseq)
    function new(string name = "axi_sram_cap_ruser_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] lo, hi;
      bit        u0, u1;
      await_reset();

      // Valid capability -> both beats 1.
      write_cap(32'd9, 64'h0000_00A0, 64'h5555_5555_5555_5555, 64'h6666_6666_6666_6666, 1'b1);
      read_cap(32'd9, 64'h0000_00A0, lo, hi, u0, u1);
      if (u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf("valid cap ruser=%0b%0b (expect 11)", u1, u0))

      // Untagged region -> both beats 0.
      write_cap(32'd9, 64'h0000_00C0, 64'h7777_7777_7777_7777, 64'h8888_8888_8888_8888, 1'b0);
      read_cap(32'd9, 64'h0000_00C0, lo, hi, u0, u1);
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf("untagged cap ruser=%0b%0b (expect 00)", u1, u0))
    endtask
  endclass
