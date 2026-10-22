// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // random_data -- N random (8-byte-aligned addr, data) write/read pairs.
  class axi_sram_random_data_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_random_data_vseq)
    function new(string name = "axi_sram_random_data_vseq"); super.new(name); endfunction

    task body();
      int        n_iters = 32;
      bit [63:0] exp [bit [63:0]];   // addr -> expected data
      bit [63:0] got;
      await_reset();
      for (int i = 0; i < n_iters; i++) begin
        bit [63:0] addr = 64'($urandom_range(0, (SramSize/WordBytes) - 1)) << 3;
        bit [63:0] val  = {$urandom, $urandom};
        exp[addr] = val;
        write_word(32'd3, addr, val);
      end
      foreach (exp[addr]) begin
        read_word(32'd3, addr, got);
        if (got != exp[addr])
          `uvm_error(get_full_name(), $sformatf("@0x%0h: expected 0x%016h, got 0x%016h",
                     addr, exp[addr], got))
      end
      `uvm_info(get_full_name(), $sformatf("random_data: %0d locations checked", exp.size()),
                UVM_LOW)
    endtask
  endclass
