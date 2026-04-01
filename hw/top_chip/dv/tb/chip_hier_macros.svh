// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// DUT related
`define SYSTEM_HIER tb.dut
`define CPU_HIER `SYSTEM_HIER.i_cva6
`define SRAM_MEM_HIER `SYSTEM_HIER.u_axi_sram.u_ram.mem
`define TAG_MEM_HIER `SYSTEM_HIER.u_axi_sram.u_tag_ram.mem
`define ROM_MEM_HIER `SYSTEM_HIER.u_rom_ctrl.gen_rom_scramble_disabled.u_rom.u_prim_rom.mem

// Testbench related
`define SIM_SRAM_IF u_sim_sram.u_sim_sram_if
