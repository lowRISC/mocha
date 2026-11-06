// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // execute_from_sram -- instruction-flavoured reads (arprot[2]=1) return stored
  // words identically to data reads, as single fetches and as a sequential burst.
  class axi_sram_execute_from_sram_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_execute_from_sram_vseq)
    function new(string name = "axi_sram_execute_from_sram_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] base = 64'h0000_0800;
      bit [63:0] prog [4];
      bit [63:0] data[$];
      bit        ruser[$];
      await_reset();
      foreach (prog[i]) begin
        prog[i] = 64'h0000_0000_1000_0000 | i;
        write_word(32'd6, base + i * WordBytes, prog[i]);
      end
      // Fetch each word as an instruction-protected single read (prot[2]=1).
      foreach (prog[i]) begin
        read_generic(32'd6, base + i * WordBytes, 1, 3'd3, 3'b100, data, ruser);
        if (data[0] != prog[i])
          `uvm_error(get_full_name(), $sformatf("fetch @0x%0h: expected 0x%016h got 0x%016h",
                     base + i * WordBytes, prog[i], data[0]))
      end
      // Sequential instruction burst fetch of the whole program.
      read_generic(32'd6, base, 4, 3'd3, 3'b100, data, ruser);
      foreach (prog[i])
        if (data[i] != prog[i])
          `uvm_error(get_full_name(), $sformatf("burst fetch beat %0d: want 0x%016h got 0x%016h",
                     i, prog[i], data[i]))
    endtask
  endclass
