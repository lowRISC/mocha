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
  import axi4_vip_pkg::*;

  import top_chip_dv_env_pkg::SW_DV_START_ADDR;
  import top_chip_dv_env_pkg::SW_DV_TEST_STATUS_ADDR;
  import top_chip_dv_env_pkg::SW_DV_LOG_ADDR;

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
  axi4_vip_if axi4_mgr_if[NUM_OF_MGR_AXI_IFS]();
  axi4_vip_if axi4_sub_if[NUM_OF_SUB_AXI_IFS]();

  // AXI VIP connections are included from a separate file for better reading
  `include "axi_vip_connections.sv"

  // ------ Mock DRAM ------
  top_pkg::axi_dram_req_t  dram_req;
  top_pkg::axi_dram_resp_t dram_resp;

  dram_wrapper_sim u_dram_wrapper(
    // Clock and reset.
    .clk_i      (dut.clkmgr_clocks.clk_main_infra),
    .rst_ni     (dut.rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    // AXI interface.
    .axi_req_i  (dram_req                        ),
    .axi_resp_o (dram_resp                       )
  );

  // ------ DUT ------
  top_chip_system #() dut (
    // Clock and reset.
    .clk_i                (clk              ),
    .rst_ni               (rst_n            ),
    // UART receive and transmit.
    .uart_rx_i            (uart_if.uart_rx  ),
    .uart_tx_o            (uart_if.uart_tx  ),
    // External Mailbox port
    .axi_mailbox_req_i    ('0               ),
    .axi_mailbox_resp_o   (                 ),
    .mailbox_ext_irq_o    (                 ),
    // SPI device receive and transmit.
    // TODO SPI device signals are currently tied off, need to be connected to a SPI agent
    .spi_device_sck_i     (1'b0             ),
    .spi_device_csb_i     (1'b1             ),
    .spi_device_sd_o      (                 ),
    .spi_device_sd_en_o   (                 ),
    .spi_device_sd_i      (4'hF             ),
    .spi_device_tpm_csb_i (1'b0             ),
    // DRAM.
    .dram_req_o           (dram_req         ),
    .dram_resp_i          (dram_resp        )
  );

  // Signals to connect the sink
  top_pkg::axi_req_t  sim_sram_cpu_req;
  top_pkg::axi_resp_t sim_sram_cpu_resp;
  top_pkg::axi_req_t  sim_sram_xbar_req;
  top_pkg::axi_resp_t sim_sram_xbar_resp;

  // Instantiate the AXI sink to intercept the AXI traffic within the simulation memory range
  // to provide a dedicated channel for SW-to-DV communication.
  sim_sram_axi_sink u_sim_sram (
    .clk_i          (clk                ),
    .rst_ni         (rst_n              ),
    .cpu_req_i      (sim_sram_cpu_req   ),
    .cpu_resp_o     (sim_sram_cpu_resp  ),
    .xbar_req_o     (sim_sram_xbar_req  ),
    .xbar_resp_i    (sim_sram_xbar_resp )
  );

  // Capture inputs FROM the DUT (Monitoring)
  assign sim_sram_cpu_req   = dut.cva6_to_sim_req;
  assign sim_sram_xbar_resp = dut.xbar_host_resp[top_pkg::CVA6];

  // Force outputs INTO the DUT (Overriding)
  // We break the direct connection inside the RTL using forces
  initial begin
    // Ensure we wait for build/elaboration phases if necessary,
    // though force on static hierarchy works at time 0.
    force dut.xbar_host_req[top_pkg::CVA6] = sim_sram_xbar_req;
    force dut.sim_to_cva6_resp             = sim_sram_cpu_resp;
  end

  // ------ Memory backdoor accesses ------
  if (prim_pkg::PrimTechName == "Generic") begin : gen_mem_bkdr_utils
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
  end : gen_mem_bkdr_utils

  // Bind the SW test status interface directly to the sim SRAM interface.
  bind `SIM_SRAM_IF sw_test_status_if u_sw_test_status_if (
    .addr     (req.aw.addr[31:0]),  // Only lower 32-bits is enough (see AddrUpperBitsZero_A)
    .data     (req.w.data[15:0]),   // Test status is 16-bits wide
    .fetch_en (1'b0), // use constant, as there is no pwrmgr-provided CPU fetch enable signal
    .*
  );

  // Bind the SW logger interface directly to the sim SRAM interface.
  bind `SIM_SRAM_IF sw_logger_if u_sw_logger_if (
    .addr (req.aw.addr[31:0]), // Only lower 32-bits is enough (see AddrUpperBitsZero_A)
    .data (req.w.data[31:0]),  // Log data is 32-bits wide (see DataUpperBitsZero_A)
    .*
  );

  // Check that signals going into sw_test_status_if and sw_logger_if are always less 32-bits wide
  `ASSERT(AddrUpperBitsZero_A,
    `SIM_SRAM_IF.req.aw_valid |-> (`SIM_SRAM_IF.req.aw.addr[top_pkg::AxiAddrWidth-1:32] == 0),
    `SIM_SRAM_IF.clk_i, !`SIM_SRAM_IF.rst_ni)

  `ASSERT(DataUpperBitsZero_A,
    `SIM_SRAM_IF.req.w_valid |-> (`SIM_SRAM_IF.req.w.strb[top_pkg::AxiStrbWidth-1:4] == 0),
    `SIM_SRAM_IF.clk_i, !`SIM_SRAM_IF.rst_ni)

  `ASSERT_INIT(AddrSwDv_A, $size(SW_DV_START_ADDR) == 32)

  // ------ Initialisation ------
  initial begin
    // Set base of SW DV special write locations
    `SIM_SRAM_IF.start_addr                               = SW_DV_START_ADDR;
    `SIM_SRAM_IF.sw_dv_size                               = SW_DV_SIZE;
    `SIM_SRAM_IF.u_sw_test_status_if.sw_test_status_addr  = SW_DV_TEST_STATUS_ADDR;
    `SIM_SRAM_IF.u_sw_logger_if.sw_log_addr               = SW_DV_LOG_ADDR;

    // Start clock and reset generators
    sys_clk_if.set_active();
    peri_clk_if.set_active();

    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "sys_clk_if", sys_clk_if);
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "peri_clk_if", peri_clk_if);
    uvm_config_db#(virtual uart_if)::set(null, "*.env.m_uart_agent*", "vif", uart_if);

    // AXI VIFs
    uvm_config_db#(virtual axi4_vip_if)::set(null, "*.m_mgr_axi_CVA6.*",       "vif", axi4_mgr_if[top_pkg::CVA6]);
    uvm_config_db#(virtual axi4_vip_if)::set(null, "*.m_sub_axi_SRAM.*",       "vif", axi4_sub_if[top_pkg::SRAM]);
    uvm_config_db#(virtual axi4_vip_if)::set(null, "*.m_sub_axi_Mailbox.*",    "vif", axi4_sub_if[top_pkg::Mailbox]);
    uvm_config_db#(virtual axi4_vip_if)::set(null, "*.m_sub_axi_TlCrossbar.*", "vif", axi4_sub_if[top_pkg::TlCrossbar]);
    uvm_config_db#(virtual axi4_vip_if)::set(null, "*.m_sub_axi_DRAM.*",       "vif", axi4_sub_if[top_pkg::DRAM]);
    
    // SW logger and test status interfaces.
    uvm_config_db#(virtual sw_test_status_if)::set(
        null, "*.env", "sw_test_status_vif", `SIM_SRAM_IF.u_sw_test_status_if);
    uvm_config_db#(virtual sw_logger_if)::set(
        null, "*.env", "sw_logger_vif", `SIM_SRAM_IF.u_sw_logger_if);

    // Run UVM test
    run_test();
  end
endmodule : tb
