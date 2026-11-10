// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // burst_last -- multi-beat burst round-trips; last beat flagged correctly.
  class axi_sram_burst_last_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_last_vseq)

    function new(string name = "axi_sram_burst_last_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0] addr = 64'h0000_0300;
      int        nbeats = 4;
      bit [63:0] words[$];
      await_reset();

      for (int i = 0; i < nbeats; i++) begin
        words.push_back(64'h1000_0000_0000_0000 | i);
      end
      write_burst_words(32'd4, addr, words);

      // run_read checks RLAST on every beat.
      read_generic(32'd4, addr, nbeats, 3'd3, 3'd0);
    endtask
  endclass
