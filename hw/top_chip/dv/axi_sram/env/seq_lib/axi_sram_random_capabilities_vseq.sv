// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // random_capabilities -- N random 16-byte-aligned capability write/read pairs.
  class axi_sram_random_capabilities_vseq extends axi_sram_base_vseq;
    `uvm_object_utils(axi_sram_random_capabilities_vseq)
    function new(string name = "axi_sram_random_capabilities_vseq"); super.new(name); endfunction

    task body();
      int        n_iters = 32;
      bit [63:0] exp_lo [bit [63:0]];
      bit [63:0] exp_hi [bit [63:0]];
      bit [63:0] rl, ru;
      bit        u0, u1;
      await_reset();
      for (int i = 0; i < n_iters; i++) begin
        bit [63:0] addr = 64'($urandom_range(0, (SramSize/CapBytes) - 1)) << 4;
        bit [63:0] lo   = {$urandom, $urandom};
        bit [63:0] hi   = {$urandom, $urandom};
        exp_lo[addr] = lo;
        exp_hi[addr] = hi;
        write_cap(32'd4, addr, lo, hi, 1'b1);
      end
      foreach (exp_lo[addr]) begin
        read_cap(32'd4, addr, rl, ru, u0, u1);
        if (rl != exp_lo[addr] || ru != exp_hi[addr] || u0 != 1 || u1 != 1) begin
          `uvm_error(get_full_name(), $sformatf(
                     "@0x%0h: lo=%016h/%016h hi=%016h/%016h tag=%0b", addr,
                     rl, exp_lo[addr], ru, exp_hi[addr], u0))
        end
      end
      `uvm_info(get_full_name(),
                $sformatf("random_capabilities: %0d capabilities checked", exp_lo.size()), UVM_LOW)
    endtask
  endclass
