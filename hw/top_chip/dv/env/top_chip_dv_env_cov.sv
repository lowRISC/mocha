// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_env_cov extends uvm_component;
  `uvm_component_param_utils(top_chip_dv_env_cov)

  top_chip_dv_env_cfg cfg;

  // Standard SV/UVM methods
  extern function new(string name = "", uvm_component parent = null);
endclass

function top_chip_dv_env_cov::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new
