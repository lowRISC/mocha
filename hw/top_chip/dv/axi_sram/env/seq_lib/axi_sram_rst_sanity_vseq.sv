// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // rst_sanity -- DUT leaves reset cleanly and accepts its first transaction.
  class axi_sram_rst_sanity_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_rst_sanity_vseq)
    function new(string name = "axi_sram_rst_sanity_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] rdata;
      await_reset();
      // The very first transaction after reset must complete and round-trip.
      write_word(32'd1, 64'h0, 64'hA5A5_5A5A_C3C3_3C3C);
      read_word(32'd1, 64'h0, rdata);
      if (rdata != 64'hA5A5_5A5A_C3C3_3C3C)
        `uvm_error(get_full_name(), $sformatf("rst_sanity: read 0x%016h", rdata))
    endtask
  endclass
