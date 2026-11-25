// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// write_read: a single-beat 8-byte write then readback.
class axi_sram_write_read_vseq extends axi_sram_base_vseq;
  `uvm_object_utils(axi_sram_write_read_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : axi_sram_write_read_vseq


function axi_sram_write_read_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_sram_write_read_vseq::body();
  bit [63:0] addr = 64'h0000_0008;
  await_reset();
  write_word(32'd1, addr, 64'hDEAD_BEEF_CAFE_1234);
  read_word(32'd1, addr);
endtask : body
