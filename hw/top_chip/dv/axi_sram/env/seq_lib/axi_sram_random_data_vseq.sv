// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // random_data -- N random (8-byte-aligned addr, data) write/read pairs.
  class axi_sram_random_data_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_random_data_vseq)

    function new(string name = "axi_sram_random_data_vseq");
      super.new(name);
    endfunction

    task body();
      int n_iters = 32;
      bit written [bit [63:0]];
      await_reset();
      for (int i = 0; i < n_iters; i++) begin
        bit [63:0] addr = 64'($urandom_range(0, (SramSize/WordBytes) - 1)) << 3;
        written[addr] = 1'b1;
        write_word(32'd3, addr, {$urandom, $urandom});
      end
      foreach (written[addr]) begin
        read_word(32'd3, addr);
      end
    endtask
  endclass
