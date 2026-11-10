// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // wuser_mismatch -- a cap-shaped write whose beats disagree on wuser is not a full capability
  // write, so it must round-trip its data and leave the covering slot's tag clear. Both beat
  // orders are driven, because the tag RAM is written on every beat.
  //
  // TODO(lowRISC/mocha#717): the (0, 1) order forges a tag.
  class axi_sram_wuser_mismatch_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_wuser_mismatch_vseq)

    function new(string name = "axi_sram_wuser_mismatch_vseq");
      super.new(name);
    endfunction

    // Drive a cap-shaped write with the given per-beat wuser, then read the slot back.
    protected task automatic check_mismatch(bit [31:0] id, bit [63:0] addr,
                                            bit user0, bit user1);
      write_cap_user(id, addr, 64'h1234_1234_1234_1234 + addr, 64'h5678_5678_5678_5678 + addr,
                     user0, user1);
      read_cap(id, addr);
    endtask

    task body();
      await_reset();
      // 16-byte aligned, otherwise well-formed capability writes.
      check_mismatch(32'd13, 64'h0000_00B0, 1'b1, 1'b0);
      check_mismatch(32'd13, 64'h0000_00C0, 1'b0, 1'b1);
    endtask
  endclass
