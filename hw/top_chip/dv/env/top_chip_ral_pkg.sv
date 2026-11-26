// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package top_chip_ral_pkg;
  import uvm_pkg::*;
  import dv_base_reg_pkg::*;
  import top_pkg::TL_DW;
  import tl_peri_pkg::*;

  import clkmgr_ral_pkg::*;
  import entropy_src_ral_pkg::*;
  import gpio_ral_pkg::*;
  import i2c_ral_pkg::*;
  import pwrmgr_ral_pkg::*;
  import rom_ctrl_regs_ral_pkg::*;
  import rstmgr_ral_pkg::*;
  import rv_plic_ral_pkg::*;
  import rv_timer_ral_pkg::*;
  import spi_device_ral_pkg::*;
  import spi_host_ral_pkg::*;
  import uart_ral_pkg::*;

  // Macro includes
  `include "uvm_macros.svh"

  // File includes
  `include "top_chip_reg_block.svh"
endpackage : top_chip_ral_pkg
