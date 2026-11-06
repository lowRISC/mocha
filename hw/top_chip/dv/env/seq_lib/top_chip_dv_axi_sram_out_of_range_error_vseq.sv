// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Accesses just past the SRAM and in an unmapped gap must get DECERR: the xbar has no default
// port, so nothing outside a mapped region may reach a subordinate.

class top_chip_dv_axi_sram_out_of_range_error_vseq extends top_chip_dv_axi_driver_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_sram_out_of_range_error_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
endclass : top_chip_dv_axi_sram_out_of_range_error_vseq

function top_chip_dv_axi_sram_out_of_range_error_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_axi_sram_out_of_range_error_vseq::body();
  super.body();
  // Control: the same path still reaches a mapped subordinate.
  check_round_trip(top_pkg::SRAMBase);
  check_decerr(top_pkg::SRAMBase + top_pkg::SRAMLength);
  // Between the end of the TL crossbar region and DRAM.
  check_decerr(64'h6000_0000);
endtask : body
