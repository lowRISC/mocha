// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // burst_last -- multi-beat burst round-trips; last beat flagged correctly.
  class axi_sram_burst_last_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_last_vseq)
    function new(string name = "axi_sram_burst_last_vseq"); super.new(name); endfunction

    task body();
      bit [63:0] addr = 64'h0000_0300;
      int        nbeats = 4;
      bit [63:0] words[$];
      axi_mgr_read_burst_vseq rseq;
      await_reset();

      for (int i = 0; i < nbeats; i++) words.push_back(64'h1000_0000_0000_0000 | i);
      write_burst_words(32'd4, addr, words);

      // Read the burst back through the burst vseq so we can inspect per-beat RLAST.
      rseq = axi_mgr_read_burst_vseq::type_id::create("rb");
      if (!rseq.randomize() with { m_ar_req.m_id    == 32'd4;
                                   m_ar_req.m_addr  == local::addr;
                                   m_ar_req.m_user  == '0;
                                   m_ar_req.m_size  == 3'd3;
                                   m_ar_req.m_len   == 8'(nbeats - 1);
                                   m_ar_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "burst_last: could not randomize the burst")
      run_read(rseq, "burst_last", nbeats);

      foreach (rseq.m_read_beats[i]) begin
        bit exp_last = (i == nbeats - 1);
        if (rseq.m_read_beats[i].m_data[63:0] != (64'h1000_0000_0000_0000 | i))
          `uvm_error(get_full_name(), $sformatf("burst beat %0d data 0x%016h", i,
                     rseq.m_read_beats[i].m_data[63:0]))
        if (rseq.m_read_beats[i].m_last != exp_last)
          `uvm_error(get_full_name(), $sformatf("burst beat %0d RLAST=%0b expected %0b", i,
                     rseq.m_read_beats[i].m_last, exp_last))
      end
      `uvm_info(get_full_name(), "burst_last: 4-beat burst round-trip + RLAST OK", UVM_LOW)
    endtask
  endclass
