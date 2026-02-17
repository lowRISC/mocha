// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package top_chip_dv_env_pkg;
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import csr_utils_pkg::*;
  import mem_bkdr_util_pkg::*;
  import sw_test_status_pkg::*;
  import uart_agent_pkg::*;
  import spi_agent_pkg::*;

  // Macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  typedef enum {
    ChipMemSRAM
  } chip_mem_e;

  typedef chip_mem_e chip_mem_list_t[$];

  // Generate the list of all chip_mem_e values, this helps to simplify iterating over them with
  // foreach loops.
  const chip_mem_list_t CHIP_MEM_LIST = chip_mem_values();

  function automatic chip_mem_list_t chip_mem_values;
    chip_mem_list_t list;
    chip_mem_e tmp = tmp.first;
    do begin
      list.push_back(tmp);
      tmp = tmp.next;
    end
    while (tmp  != tmp.first);
    return list;
  endfunction : chip_mem_values

  // 1 GHz System clock
  parameter int unsigned SysClkFreq = 1_000_000_000;
  // 50 MHz Peripheral clock
  parameter int unsigned PeriClkFreq = 50_000_000;

  // SW DV special write locations for test status and logging will always fit in 32-bits
  parameter bit [31:0] SW_DV_START_ADDR       = 'h2001_0000;
  parameter bit [31:0] SW_DV_SIZE             = 'h0000_0100;        // 256 bytes reserved for SW DV
  parameter bit [31:0] SW_DV_TEST_STATUS_ADDR = SW_DV_START_ADDR + 'h00;
  parameter bit [31:0] SW_DV_LOG_ADDR         = SW_DV_START_ADDR + 'h04;

  // File includes
  `include "mem_clear_util.sv"
  `include "top_chip_dv_env_cfg.sv"
  `include "top_chip_dv_env_cov.sv"
  `include "top_chip_dv_virtual_sequencer.sv"
  `include "top_chip_dv_env.sv"
  `include "top_chip_dv_vseq_list.sv"
endpackage : top_chip_dv_env_pkg
