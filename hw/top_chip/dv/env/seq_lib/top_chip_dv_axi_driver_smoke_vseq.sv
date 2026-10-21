// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Basic smoke test which checks that the AXI driver replacing the CVA6 can write to and read back
// from a module on the xbar.

class top_chip_dv_axi_driver_smoke_vseq extends top_chip_dv_axi_driver_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_driver_smoke_vseq)

  rand int unsigned num_words;
  // SRAM-relative byte offset of the first word.
  rand bit [63:0] base_offset;

  constraint num_words_c {
    num_words inside {[4:16]};
  }

  constraint base_offset_c {
    base_offset[2:0] == 3'b0;
    base_offset + 8 * num_words <= top_pkg::SRAMLength;
  }

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
endclass : top_chip_dv_axi_driver_smoke_vseq

function top_chip_dv_axi_driver_smoke_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_axi_driver_smoke_vseq::body();
  bit [63:0] exp_data[];

  super.body();

  // Write random words to SRAM, then read them back and check them.
  `uvm_info(`gfn, $sformatf("Writing %0d words to SRAM at offset 0x%0h", num_words, base_offset),
            UVM_LOW)
  exp_data = new[num_words];
  foreach (exp_data[i]) begin
    bit [63:0] addr = top_pkg::SRAMBase + base_offset + 8 * i;
    axi_resp_e bresp;
    exp_data[i] = {$urandom, $urandom};
    write_word(addr, exp_data[i], bresp);
    `DV_CHECK_EQ(bresp, RespOkay, $sformatf("BRESP for 0x%0h", addr))
  end

  foreach (exp_data[i]) begin
    bit [63:0] addr = top_pkg::SRAMBase + base_offset + 8 * i;
    bit [63:0] act_data;
    axi_resp_e rresp;
    read_word(addr, act_data, rresp);
    `DV_CHECK_EQ(rresp, RespOkay, $sformatf("RRESP for 0x%0h", addr))
    `DV_CHECK_EQ(act_data, exp_data[i], $sformatf("read back from 0x%0h", addr))
  end
endtask : body
