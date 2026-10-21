// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // resp_id_match -- each B/R response carries the originating request's AXI ID.
  class axi_sram_resp_id_match_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_resp_id_match_vseq)
    function new(string name = "axi_sram_resp_id_match_vseq"); super.new(name); endfunction

    task body();
      bit [3:0]  ids[] = '{4'd0, 4'd3, 4'd5, 4'd7, 4'd9, 4'd11, 4'd13, 4'd15};
      bit [63:0] base = 64'h0000_0400;
      bit [63:0] got;
      await_reset();
      m_check_resp_id = 1'b1;   // run_write/run_read now assert response IDs match

      foreach (ids[i]) begin
        bit [63:0] addr = base + (i * WordBytes);
        bit [63:0] val  = 64'h1D00_0000_0000_0000 + i;
        write_word(32'(ids[i]), addr, val);    // BID == AWID checked inside run_write
        read_word(32'(ids[i]), addr, got);     // RID  == ARID checked inside run_read
        if (got != val)
          `uvm_error(get_full_name(), $sformatf("id 0x%0h: expected 0x%016h, got 0x%016h",
                     ids[i], val, got))
      end
    endtask
  endclass
