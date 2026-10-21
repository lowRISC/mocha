// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // init_value_undefined -- power-up SRAM/tag contents are undefined; an un-written read
  // completes, and a write makes the location deterministic.
  class axi_sram_init_value_undefined_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_init_value_undefined_vseq)

    function new(string name = "axi_sram_init_value_undefined_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0001_0000;   // not written by any other test
      await_reset();
      read_word(32'd5, addr);
      write_word(32'd5, addr, 64'hA5A5_5A5A_A5A5_5A5A);
      read_word(32'd5, addr);
    endtask
  endclass
