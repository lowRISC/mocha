// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // tag_isolation -- clearing one slot's tag must not disturb a neighbour's.
  class axi_sram_tag_isolation_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_tag_isolation_vseq)
    function new(string name = "axi_sram_tag_isolation_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr_a = 64'h0000_0060;
      bit [63:0] addr_b = 64'h0000_0070;   // adjacent 16-byte slot
      bit [63:0] lo, hi;
      bit        a0, a1, b0, b1;
      await_reset();
      write_cap(32'd8, addr_a, 64'hAAAA_AAAA_AAAA_AAAA, 64'hAAAA_AAAA_AAAA_AAAA, 1'b1);
      write_cap(32'd8, addr_b, 64'hBBBB_BBBB_BBBB_BBBB, 64'hBBBB_BBBB_BBBB_BBBB, 1'b1);

      // Clear A with a plain data write; B must keep its tag.
      write_word(32'd8, addr_a, 64'hDEAD_DEAD_DEAD_DEAD);
      read_cap(32'd8, addr_a, lo, hi, a0, a1);
      read_cap(32'd8, addr_b, lo, hi, b0, b1);
      if (a0 != 0) `uvm_error(get_full_name(), "tag A must be cleared")
      if (b0 != 1) `uvm_error(get_full_name(), "tag B must be unaffected")
    endtask
  endclass
