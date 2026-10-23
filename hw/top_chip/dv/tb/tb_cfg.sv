// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Elaboration config for the chip-level tb. Defining SWAP_CVA6_WITH_AXI_DRIVER replaces the CVA6
// core with axi_driver_to_cva6_bridge (see the axi_driver_to_cva6_bridge build mode in
// top_chip_sim_cfg.hjson).

config tb_cfg;
  design work.tb;
`ifdef SWAP_CVA6_WITH_AXI_DRIVER
  instance tb.dut.i_cva6 use work.axi_driver_to_cva6_bridge;
`endif
endconfig
