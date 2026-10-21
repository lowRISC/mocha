// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // burst_write_tags -- a 4-beat write with WUSER set on every beat fully writes two adjacent
  // slots, so each slot holds its own capability. Each slot is then read as a capability.
  class axi_sram_burst_write_tags_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_write_tags_vseq)

    function new(string name = "axi_sram_burst_write_tags_vseq");
      super.new(name);
    endfunction

    task body();
      bit [63:0]               addr = 64'h0000_0A00;   // 16-byte aligned
      axi_mgr_write_burst_vseq seq  = axi_mgr_write_burst_vseq::type_id::create("bwt");
      await_reset();

      for (int unsigned i = 0; i < 4; i++) begin
        seq.m_data_items.push_back(make_wd(64'hC0DE_0000_0000_0000 + i, 8'hFF, 1'b1, i == 3));
      end
      if (!seq.randomize() with { m_aw_req.m_id    == 32'd24;
                                  m_aw_req.m_addr  == local::addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstIncr; }) begin
        `uvm_fatal(get_full_name(), "burst_write_tags: could not randomize the burst")
      end
      run_write(seq, "burst_write_tags");

      read_cap(32'd24, addr);
      read_cap(32'd24, addr + CapBytes);
    endtask
  endclass
