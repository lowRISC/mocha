// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // wuser_partial_strobe -- a capability-shaped write that does not strobe every byte is not a
  // full capability write, so WUSER must not reach the tag. Driven on each beat in turn, because
  // the tag RAM is written on every beat.
  //
  // TODO(lowRISC/mocha#778): a partial strobe forges a tag.
  class axi_sram_wuser_partial_strobe_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_wuser_partial_strobe_vseq)

    function new(string name = "axi_sram_wuser_partial_strobe_vseq");
      super.new(name);
    endfunction

    // A 2-beat aligned capability write with WUSER on both beats and the given strobes, then a
    // read of the slot.
    protected task automatic check_partial(bit [31:0] id, bit [63:0] addr, bit [7:0] strb0,
                                           bit [7:0] strb1);
      axi_mgr_write_burst_vseq seq;

      seq = axi_mgr_write_burst_vseq::type_id::create("partial_cap");
      seq.m_data_items.push_back(make_wd(64'hCAFE_0001_CAFE_0001, strb0, 1'b1, 1'b0));
      seq.m_data_items.push_back(make_wd(64'hCAFE_0002_CAFE_0002, strb1, 1'b1, 1'b1));
      if (!seq.randomize() with { m_aw_req.m_id    == id;
                                  m_aw_req.m_addr  == addr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstIncr; }) begin
        `uvm_fatal(get_full_name(), "wuser_partial_strobe: could not randomize the burst")
      end
      run_write(seq, "wuser_partial_strobe");

      read_cap(id, addr);
    endtask

    task body();
      await_reset();
      // 16-byte aligned, otherwise well-formed capability writes.
      check_partial(32'd14, 64'h0000_0700, 8'h0F, 8'hFF);
      check_partial(32'd14, 64'h0000_0710, 8'hFF, 8'h0F);
    endtask
  endclass
