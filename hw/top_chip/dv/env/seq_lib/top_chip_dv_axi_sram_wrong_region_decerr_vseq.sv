// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Accesses outside the SRAM must not reach it: unmapped addresses across the gap between the TL
// crossbar region and DRAM must all get DECERR.

class top_chip_dv_axi_sram_wrong_region_decerr_vseq extends top_chip_dv_axi_driver_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_sram_wrong_region_decerr_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
endclass : top_chip_dv_axi_sram_wrong_region_decerr_vseq

function top_chip_dv_axi_sram_wrong_region_decerr_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_axi_sram_wrong_region_decerr_vseq::body();
  bit [63:0] addrs[] = '{64'h6800_0000, 64'h7000_0000, 64'h7800_0000};

  super.body();
  // Control: the same path still reaches a mapped subordinate.
  check_round_trip(top_pkg::SRAMBase);
  foreach (addrs[i]) check_decerr(addrs[i]);
endtask : body
