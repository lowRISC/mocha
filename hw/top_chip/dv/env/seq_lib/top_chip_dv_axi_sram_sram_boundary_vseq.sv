// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Pin the SRAM aperture edges: the first and last words inside it round-trip, and the words just
// below and just past it get DECERR.

class top_chip_dv_axi_sram_sram_boundary_vseq extends top_chip_dv_axi_driver_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_sram_sram_boundary_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
endclass : top_chip_dv_axi_sram_sram_boundary_vseq

function top_chip_dv_axi_sram_sram_boundary_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_axi_sram_sram_boundary_vseq::body();
  super.body();
  check_round_trip(top_pkg::SRAMBase);
  check_round_trip(top_pkg::SRAMBase + top_pkg::SRAMLength - 8);
  check_decerr(top_pkg::SRAMBase - 8);
  check_decerr(top_pkg::SRAMBase + top_pkg::SRAMLength);
endtask : body
