// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // address_boundaries -- first/last word and last capability slot.
  class axi_sram_address_boundaries_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_address_boundaries_vseq)

    function new(string name = "axi_sram_address_boundaries_vseq");
      super.new(name);
    endfunction

    task body();
      await_reset();

      // First word
      write_word(32'd3, 64'h0, 64'hF1F2_F3F4_F5F6_F7F8);
      read_word(32'd3, 64'h0);

      // Last word
      write_word(32'd3, LastWordAddr, 64'hA1A2_A3A4_A5A6_A7A8);
      read_word(32'd3, LastWordAddr);

      // Last capability slot (tagged)
      write_cap(32'd3, LastCapAddr, 64'hDEAD_BEEF_DEAD_BEEF, 64'hCAFE_BABE_CAFE_BABE, 1'b1);
      read_cap(32'd3, LastCapAddr);
    endtask
  endclass
