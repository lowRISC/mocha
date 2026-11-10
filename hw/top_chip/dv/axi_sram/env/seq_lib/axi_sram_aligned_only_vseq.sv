// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // aligned_only -- sweep several 8-byte-aligned addresses; each must round-trip.
  // (Misaligned data accesses are the interconnect's responsibility, not driven.)
  class axi_sram_aligned_only_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_aligned_only_vseq)

    function new(string name = "axi_sram_aligned_only_vseq");
      super.new(name);
    endfunction

    task body();
      int i = 0;
      await_reset();
      for (bit [63:0] addr = 64'h0000_0200; addr < 64'h0000_0280; addr += WordBytes) begin
        bit [63:0] val = 64'hC0DE_0000_0000_0000 | (i & 16'hFFFF);
        write_word(32'd10, addr, val);
        read_word(32'd10, addr);
        i++;
      end
    endtask
  endclass
