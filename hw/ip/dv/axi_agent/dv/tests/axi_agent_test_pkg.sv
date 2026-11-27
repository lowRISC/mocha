// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test package for the AXI agent self-test
package axi_agent_test_pkg;

  import uvm_pkg::*;
  import dv_lib_pkg::*;
  import axi_agent_env_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  `include "axi_agent_base_test.sv"

endpackage : axi_agent_test_pkg
