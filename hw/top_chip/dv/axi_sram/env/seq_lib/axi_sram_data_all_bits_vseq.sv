// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // data_all_bits -- walking-1 / walking-0 across all 64 data bits.
  class axi_sram_data_all_bits_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_data_all_bits_vseq)
    function new(string name = "axi_sram_data_all_bits_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0100;
      bit [63:0] val, got;
      await_reset();
      for (int b = 0; b < 64; b++) begin
        val = 64'd1 << b;                       // walking one
        write_word(32'd2, addr, val);
        read_word(32'd2, addr, got);
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("walk-1 bit %0d: wrote 0x%016h read 0x%016h",
                     b, val, got))
      end
      for (int b = 0; b < 64; b++) begin
        val = ~(64'd1 << b);                    // walking zero
        write_word(32'd2, addr, val);
        read_word(32'd2, addr, got);
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("walk-0 bit %0d: wrote 0x%016h read 0x%016h",
                     b, val, got))
      end
      `uvm_info(get_full_name(), "data_all_bits: walking 1/0 across 64 bits done", UVM_LOW)
    endtask
  endclass
