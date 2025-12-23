// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module tb;
  // Dependency packages
  import uvm_pkg::*;
  import dv_utils_pkg::*;
  import top_pkg::*;
  import mem_bkdr_util_pkg::mem_bkdr_util;
  import top_chip_dv_env_pkg::*;
  import top_chip_dv_test_pkg::*;

  // Macro includes
  `include "uvm_macros.svh"
  `include "dv_macros.svh"
  `include "chip_hier_macros.svh"

  // ------ Signals ------
  wire clk;
  wire rst_n;
  wire peri_clk;
  wire peri_rst_n;

  // ------ Interfaces ------
  clk_rst_if sys_clk_if(.clk(clk), .rst_n(rst_n));
  clk_rst_if peri_clk_if(.clk(peri_clk), .rst_n(peri_rst_n));
  uart_if uart_if();

  // ------ DUT ------
  top_chip_system #() dut (
    .clk_i              (clk              ),
    .rst_ni             (rst_n            ),
    .uart_rx_i          (uart_if.uart_rx  ),
    .uart_tx_o          (uart_if.uart_tx  )
  );

  // // ------ Memory ------
  if (`PRIM_DEFAULT_IMPL == prim_pkg::ImplGeneric) begin : gen_generic
    initial begin
      chip_mem_e    mem;
      mem_bkdr_util m_mem_bkdr_util[chip_mem_e];
      mem_clear_util tag_mem_clear;

      m_mem_bkdr_util[ChipMemSRAM] = new(
        .name                 ("mem_bkdr_util[ChipMemSRAM]"       ),
        .path                 (`DV_STRINGIFY(`SRAM_MEM_HIER)      ),
        .depth                ($size(`SRAM_MEM_HIER)              ),
        .n_bits               ($bits(`SRAM_MEM_HIER)              ),
        .err_detection_scheme (mem_bkdr_util_pkg::ErrDetectionNone),
        .system_base_addr     (top_pkg::SRAMBase                  )
      );

      // Zero-initialising the SRAM ensures valid BSS.
      m_mem_bkdr_util[ChipMemSRAM].clear_mem();
      `MEM_BKDR_UTIL_FILE_OP(m_mem_bkdr_util[ChipMemSRAM], `SRAM_MEM_HIER)

      // TODO MVy, see if required
      // Zero-initialise the SRAM Capability tags, otherwise TL-UL FIFO assertions will fire;
      // mem_bkdr_util does not handle the geometry of this memory.
      tag_mem_clear = new(
        .name   ("tag_mem_clear"              ),
        .path   (`DV_STRINGIFY(`TAG_MEM_HIER) ),
        .depth  ($size(`TAG_MEM_HIER)         ),
        .n_bits ($bits(`TAG_MEM_HIER)         )
      );
      tag_mem_clear.clear_mem();

      mem = mem.first();
      do begin
        uvm_config_db#(mem_bkdr_util)::set(
            null, "*.env", m_mem_bkdr_util[mem].get_name(), m_mem_bkdr_util[mem]);
        mem = mem.next();
      end while (mem != mem.first());
    end
  end : gen_generic

  // Bind the SW test status interface directly to the sim SRAM interface.
  bind `SIM_SRAM_IF sw_test_status_if u_sw_test_status_if (
    .addr     (tl_h2d.a_address),
    .data     (tl_h2d.a_data[15:0]),
    .fetch_en (1'b0), // use constant, as there is no pwrmgr-provided CPU fetch enable signal
    .*
  );

  // Bind the SW logger interface directly to the sim SRAM interface.
  bind `SIM_SRAM_IF sw_logger_if u_sw_logger_if (
    .addr (tl_h2d.a_address),
    .data (tl_h2d.a_data),
    .*
  );

  // ------ Initialisation ------
  initial begin
    // Set base of SW DV special write locations
    `SIM_SRAM_IF.start_addr = SW_DV_START_ADDR;
    `SIM_SRAM_IF.u_sw_test_status_if.sw_test_status_addr = SW_DV_TEST_STATUS_ADDR;
    `SIM_SRAM_IF.u_sw_logger_if.sw_log_addr = SW_DV_LOG_ADDR;

    // Start clock and reset generators
    sys_clk_if.set_active();
    peri_clk_if.set_active();

    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "sys_clk_if", sys_clk_if);
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "peri_clk_if", peri_clk_if);
    uvm_config_db#(virtual uart_if)::set(null, "*.env.m_uart_agent*", "vif", uart_if);

    // SW logger and test status interfaces.
    uvm_config_db#(virtual sw_test_status_if)::set(
        null, "*.env", "sw_test_status_vif", `SIM_SRAM_IF.u_sw_test_status_if);
    uvm_config_db#(virtual sw_logger_if)::set(
        null, "*.env", "sw_logger_vif", `SIM_SRAM_IF.u_sw_logger_if);

    // Run UVM test
    run_test();
  end
endmodule : tb
