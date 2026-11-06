// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // init_value_undefined -- power-up SRAM/tag contents are undefined; only assert
  // that an un-written read completes and that a write makes it deterministic.
  class axi_sram_init_value_undefined_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_init_value_undefined_vseq)
    function new(string name = "axi_sram_init_value_undefined_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0001_0000;   // not written by any other test
      bit [63:0] pre, post;
      await_reset();
      // No assertion on the value: just confirm the read completes (run_read checks the beats).
      read_word(32'd5, addr, pre);
      `uvm_info(get_full_name(), $sformatf("un-written read @0x%0h = 0x%016h (don't-care)",
                addr, pre), UVM_LOW)
      // After a write the location is deterministic.
      write_word(32'd5, addr, 64'hA5A5_5A5A_A5A5_5A5A);
      read_word(32'd5, addr, post);
      if (post != 64'hA5A5_5A5A_A5A5_5A5A)
        `uvm_error(get_full_name(), $sformatf("value not defined after write: 0x%016h", post))
    endtask
  endclass
