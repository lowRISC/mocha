// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// READY policy for AW, W or AR. AXI permits READY before VALID, dropping READY before VALID, or
// waiting for VALID (AMBA AXI H.c A3.2.1). With no VALID waiting, assert READY with
// m_ready_before_valid_pct percent probability: 100 allows back-to-back transfers and 0 waits for
// VALID. Once VALID waits without READY, delay another m_min_valid_to_ready to m_max_valid_to_ready
// cycles, chosen per transfer, then assert READY.

class axi_sub_ready_cfg extends uvm_object;
  `uvm_object_utils(axi_sub_ready_cfg)

  int unsigned m_ready_before_valid_pct = 100;
  int unsigned m_min_valid_to_ready     = 0;
  int unsigned m_max_valid_to_ready     = 0;

  // Standard SV/UVM methods
  extern function new(string name = "");
endclass : axi_sub_ready_cfg


function axi_sub_ready_cfg::new(string name = "");
  super.new(name);
endfunction : new
