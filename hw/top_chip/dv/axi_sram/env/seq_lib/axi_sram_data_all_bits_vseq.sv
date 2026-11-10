// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // data_all_bits -- walking-1 / walking-0 across all 64 data bits.
  class axi_sram_data_all_bits_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_data_all_bits_vseq)

    function new(string name = "axi_sram_data_all_bits_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0100;
      await_reset();
      for (int b = 0; b < 64; b++) begin
        write_word(32'd2, addr, 64'd1 << b);      // walking one
        read_word(32'd2, addr);
      end
      for (int b = 0; b < 64; b++) begin
        write_word(32'd2, addr, ~(64'd1 << b));   // walking zero
        read_word(32'd2, addr);
      end
    endtask
  endclass
