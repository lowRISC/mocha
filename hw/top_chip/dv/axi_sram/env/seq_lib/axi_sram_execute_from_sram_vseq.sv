// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // execute_from_sram -- instruction-flavoured reads (arprot[2]=1) return stored
  // words identically to data reads, as single fetches and as a sequential burst.
  class axi_sram_execute_from_sram_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_execute_from_sram_vseq)

    function new(string name = "axi_sram_execute_from_sram_vseq");
      super.new(name);
    endfunction

    task body();
      localparam int unsigned NumWords = 4;
      bit [63:0] base = 64'h0000_0800;
      await_reset();
      for (int i = 0; i < NumWords; i++) begin
        write_word(32'd6, base + i * WordBytes, 64'h0000_0000_1000_0000 | i);
      end
      // Fetch each word as an instruction-protected single read (prot[2]=1).
      for (int i = 0; i < NumWords; i++) begin
        read_generic(32'd6, base + i * WordBytes, 1, 3'd3, 3'b100);
      end
      // Sequential instruction burst fetch of the whole program.
      read_generic(32'd6, base, NumWords, 3'd3, 3'b100);
    endtask
  endclass
