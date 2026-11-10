// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // random_capabilities -- N random 16-byte-aligned capability write/read pairs.
  class axi_sram_random_capabilities_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_random_capabilities_vseq)

    function new(string name = "axi_sram_random_capabilities_vseq");
      super.new(name);
    endfunction

    task body();
      int n_iters = 32;
      bit written [bit [63:0]];
      await_reset();
      for (int i = 0; i < n_iters; i++) begin
        bit [63:0] addr = 64'($urandom_range(0, (SramSize/CapBytes) - 1)) << 4;
        written[addr] = 1'b1;
        write_cap(32'd4, addr, {$urandom, $urandom}, {$urandom, $urandom}, 1'b1);
      end
      foreach (written[addr]) begin
        read_cap(32'd4, addr);
      end
    endtask
  endclass
