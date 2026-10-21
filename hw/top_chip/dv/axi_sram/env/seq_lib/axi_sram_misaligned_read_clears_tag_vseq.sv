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
      await_reset();
      write_cap(32'd17, addr, 64'hAAAA_0001_AAAA_0001, 64'hAAAA_0002_AAAA_0002, 1'b1);
      read_cap(32'd17, addr);

      // Starts at addr+8, so neither beat lands where a capability read's beats would.
      read_generic(32'd17, addr + 8, 2, 3'd3, 3'd0);

      // A properly aligned read of the same slot still sees the capability.
      read_cap(32'd17, addr);
    endtask
  endclass
