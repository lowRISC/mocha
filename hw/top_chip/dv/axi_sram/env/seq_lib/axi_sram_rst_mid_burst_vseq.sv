// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // rst_mid_burst -- reset asserted part-way through a write burst. The DUT must come back usable.
  //
  // How much of the aborted burst reached memory is undefined and the monitor drops it, so its
  // region is never read back. The check is a fresh round trip afterwards, out of the burst's
  // reach.
  class axi_sram_rst_mid_burst_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_rst_mid_burst_vseq)
    function new(string name = "axi_sram_rst_mid_burst_vseq"); super.new(name); endfunction

    task body();
      localparam int unsigned   Beats     = 16;
      // 16 INCR beats from AbortAddr span 128 bytes, nowhere near CheckAddr.
      localparam bit [63:0]     AbortAddr = 64'h0000_1000;
      localparam bit [63:0]     CheckAddr = 64'h0000_8000;
      localparam bit [63:0]     CapAddr   = 64'h0000_8010;
      axi_mgr_write_burst_vseq  seq;
      bit [63:0]                rdata, lo, hi;
      bit                       u0, u1;
      await_reset();

      seq = axi_mgr_write_burst_vseq::type_id::create("aborted_burst");
      for (int unsigned i = 0; i < Beats; i++) begin
        seq.m_data_items.push_back(make_wd(64'hA5A5_0000_0000_0000 + i, 8'hFF, 1'b0,
                                           i == Beats - 1));
      end
      if (!seq.randomize() with { m_aw_req.m_id    == 32'd7;
                                  m_aw_req.m_addr  == AbortAddr;
                                  m_aw_req.m_user  == '0;
                                  m_aw_req.m_size  == 3'd3;
                                  m_aw_req.m_burst == BurstIncr; })
        `uvm_fatal(get_full_name(), "rst_mid_burst: could not randomize the burst")
      wire_write(seq);

      fork
        seq.start(null);
        begin
          // Far enough in that beats are flowing, far short of the 16th.
          p_sequencer.clk_rst_vif.wait_clks(6);
          p_sequencer.clk_rst_vif.apply_reset();
        end
      join

      // Bound the reset on both sides, so a timing change cannot leave the test checking nothing.
      if (seq.rsp == null)
        `uvm_fatal(get_full_name(), "the aborted burst produced no status")
      if (!seq.rsp.m_aw_status.m_sending_complete)
        `uvm_error(get_full_name(),
                   "reset landed before the write request was sent, so no burst was in flight")
      if (seq.rsp.m_write_response != null)
        `uvm_error(get_full_name(),
                   "reset did not cut the burst: the B response arrived, so nothing was aborted")

      await_reset();

      // The DUT must be fully usable again: data and a capability tag both round-trip.
      write_word(32'd8, CheckAddr, 64'hFACE_B00C_1234_5678);
      read_word(32'd8, CheckAddr, rdata);
      if (rdata != 64'hFACE_B00C_1234_5678)
        `uvm_error(get_full_name(), $sformatf("post-reset data readback 0x%016h", rdata))

      write_cap(32'd9, CapAddr, 64'hCAFE_0001_CAFE_0001, 64'hCAFE_0002_CAFE_0002, 1'b1);
      read_cap(32'd9, CapAddr, lo, hi, u0, u1);
      if (lo != 64'hCAFE_0001_CAFE_0001 || hi != 64'hCAFE_0002_CAFE_0002 || u0 != 1 || u1 != 1)
        `uvm_error(get_full_name(), $sformatf(
                   "post-reset capability readback lo=0x%016h hi=0x%016h u=%0b%0b", lo, hi, u1, u0))
    endtask
  endclass
