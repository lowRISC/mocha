// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // wuser_mismatch -- a cap-shaped write whose beats disagree on wuser is not a full capability
  // write, so it must round-trip its data and leave the covering slot's tag clear. Both beat
  // orders are driven, because the tag RAM is written on every beat.
  //
  // FAILS on the (0, 1) order: the stored tag reduces to the last beat's wuser, so that order
  // forges one. Issue 717. Stated against the architectural requirement.
  class axi_sram_wuser_mismatch_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_wuser_mismatch_vseq)
    function new(string name = "axi_sram_wuser_mismatch_vseq"); super.new(name); endfunction

    // Drive a cap-shaped write with the given per-beat wuser, then require the data back and the
    // tag clear.
    protected task automatic check_mismatch(bit [31:0] id, bit [63:0] addr,
                                            bit user0, bit user1);
      bit [63:0] lower = 64'h1234_1234_1234_1234 + addr;
      bit [63:0] upper = 64'h5678_5678_5678_5678 + addr;
      bit [63:0] rl, ru;
      bit        u0, u1;

      write_cap_user(id, addr, lower, upper, user0, user1);
      read_cap(id, addr, rl, ru, u0, u1);
      if (rl != lower || ru != upper)
        `uvm_error(get_full_name(), $sformatf(
                   "wuser=(%0b,%0b) @0x%0h: data lost: lo=0x%016h hi=0x%016h",
                   user0, user1, addr, rl, ru))
      if (u0 != 0 || u1 != 0)
        `uvm_error(get_full_name(), $sformatf(
                   "wuser=(%0b,%0b) @0x%0h: forged tag, readback ruser=%0b%0b",
                   user0, user1, addr, u1, u0))
    endtask

    task body();
      await_reset();
      // 16-byte aligned, otherwise well-formed capability writes.
      check_mismatch(32'd13, 64'h0000_00B0, 1'b1, 1'b0);
      check_mismatch(32'd13, 64'h0000_00C0, 1'b0, 1'b1);
    endtask
  endclass
