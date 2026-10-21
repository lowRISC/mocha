// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // burst_wrap -- the "partial burst out of range" scenario (u0s8nt): a burst that
  // starts in-SRAM whose later beats cross the aperture top. Such a burst would cross
  // the 4 KiB boundary at the SRAM top, which AXI4 (A4.1.2) forbids, so a
  // compliant master cannot issue it -- u0s8nt is met by proxy of AXI4. This test
  // confirms the protocol layer actually rejects it: the VIP's request item carries
  // no_4kb_boundary_crossing_c, so a boundary-crossing request fails to randomise.
  //
  // (Were it forced through anyway, axi_sram has no range check -- mem_err_i=0, it
  // masks the address -- so the over-the-top beat would wrap to SRAM word 0. But the
  // xbar already blocks fully-out-of-range accesses and AXI4 blocks the partial case,
  // so axi_sram never sees an out-of-aperture address; range enforcement is by proxy.)
  class axi_sram_burst_wrap_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_burst_wrap_vseq)
    function new(string name = "axi_sram_burst_wrap_vseq"); super.new(name); endfunction

    task body();
      axi_txn_request_item aw = axi_txn_request_item::type_id::create("aw");
      bit legal, control;
      await_reset();
      // 2-beat INCR (8-byte) burst whose second beat lands one word past the aperture
      // top -- i.e. it crosses the 4 KiB boundary at SRAMLength.
      legal = aw.randomize() with {
        m_addr  == (top_pkg::SRAMLength - WordBytes);
        m_len   == 8'd1;
        m_size  == 3'd3;
        m_burst == BurstIncr;
      };
      // Positive control: the same burst one word lower stays inside the boundary and must
      // randomise, so a rejection above can only have come from the crossing itself and not from
      // some other constraint on the item.
      control = aw.randomize() with {
        m_addr  == (top_pkg::SRAMLength - 2 * WordBytes);
        m_len   == 8'd1;
        m_size  == 3'd3;
        m_burst == BurstIncr;
      };
      if (!control)
        `uvm_error(get_full_name(), {"burst_wrap: a burst wholly inside the aperture failed to ",
                  "randomise, so the rejection above says nothing about the 4 KiB boundary"})

      if (legal)
        `uvm_error(get_full_name(), {"burst_wrap: a burst crossing the SRAM aperture top ",
                  "randomised as legal -- the AXI4 4 KiB-boundary constraint is missing"})
      else if (control)
        `uvm_info(get_full_name(), {"burst_wrap: a burst crossing the SRAM aperture top is ",
                  "rejected by the AXI4 4 KiB-boundary constraint; the partial-out-of-range ",
                  "scenario cannot be issued by a compliant master, so u0s8nt is met by proxy"},
                  UVM_LOW)
    endtask
  endclass
