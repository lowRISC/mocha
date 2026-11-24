// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Elaboration config for the chip-level tb. Defining SWAP_CVA6_WITH_AXI_DRIVER replaces the CVA6
// core with axi_driver_to_cva6_bridge (see the axi_driver_to_cva6_bridge build mode in
// top_chip_sim_cfg.hjson). The two bind modules add the AXI protocol assertions to every axi_if.

config tb_cfg;
  design tb axi_mgr_protocol_bind axi_sub_protocol_bind;
`ifdef SWAP_CVA6_WITH_AXI_DRIVER
  instance tb.dut.i_cva6 use axi_driver_to_cva6_bridge;
`endif
endconfig
