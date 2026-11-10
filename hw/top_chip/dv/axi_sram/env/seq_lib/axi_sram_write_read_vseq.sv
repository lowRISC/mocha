// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // write_read: a single-beat 8-byte write then readback.
  class axi_sram_write_read_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_write_read_vseq)

    function new(string name = "axi_sram_write_read_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0008;
      await_reset();
      write_word(32'd1, addr, 64'hDEAD_BEEF_CAFE_1234);
      read_word(32'd1, addr);
    endtask
  endclass
