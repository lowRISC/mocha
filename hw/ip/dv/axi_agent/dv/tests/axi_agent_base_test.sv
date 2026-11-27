// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base test for the AXI agent self-test

class axi_agent_base_test extends dv_base_test #(
    .CFG_T(axi_agent_env_cfg),
    .ENV_T(axi_agent_env)
  );
  `uvm_component_utils(axi_agent_base_test)

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
endclass : axi_agent_base_test


function axi_agent_base_test::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new
