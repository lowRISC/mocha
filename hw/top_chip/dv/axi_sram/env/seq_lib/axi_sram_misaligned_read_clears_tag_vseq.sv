// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // misaligned_read_clears_tag -- a 2-beat, 8-byte read that starts half way into a capability
  // slot is capability-shaped but not capability-aligned, so it must return a cleared tag on both
  // beats. The stored tag is unaffected: the read-side gate only decides what is reported.
  class axi_sram_misaligned_read_clears_tag_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_misaligned_read_clears_tag_vseq)
    function new(string name = "axi_sram_misaligned_read_clears_tag_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0900;   // 16-byte aligned slot base
      bit [63:0] lo, hi;
      bit        u0, u1;
      bit [63:0] data[$];
      bit        ruser[$];
      await_reset();
      write_cap(32'd17, addr, 64'hAAAA_0001_AAAA_0001, 64'hAAAA_0002_AAAA_0002, 1'b1);
      read_cap(32'd17, addr, lo, hi, u0, u1);
      if (u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), "precondition: stored cap must be valid")

      // Starts at addr+8, so neither beat lands where a capability read's beats would.
      read_generic(32'd17, addr + 8, 2, 3'd3, 3'd0, data, ruser);
      if (ruser[0] != 0 || ruser[1] != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "misaligned capability read returned ruser=%0b%0b (expect 00)",
                   ruser[1], ruser[0]))

      // A properly aligned read of the same slot still sees the capability.
      read_cap(32'd17, addr, lo, hi, u0, u1);
      if (u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "stored tag changed by a misaligned read (ruser=%0b%0b)", u1, u0))
    endtask
  endclass
