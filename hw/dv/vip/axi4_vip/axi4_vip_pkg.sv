// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef __AXI4_VIP_PKG_SV
`define __AXI4_VIP_PKG_SV

`include "axi4_vip_if.sv"

package axi4_vip_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  `include "axi4_vip_defines.svh"
  `include "axi4_vip_types.svh"

  `include "axi4_vip_cfg.svh"

  `include "axi4_vip_item.svh"

  `include "axi4_vip_driver.svh"
  `include "axi4_vip_sequencer.svh"

  `include "axi4_vip_monitor.svh"
  `include "axi4_vip_master_agent.svh"
  `include "axi4_vip_slave_agent.svh"

  `include "axi4_vip_env.svh"

endpackage

`endif // __AXI4_VIP_PKG_SV