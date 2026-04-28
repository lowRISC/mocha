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
  import gpio_env_pkg::NUM_GPIOS;

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

  // GPIO connections
  wire  [NUM_GPIOS-1:0] gpio_pads;    // A wire connected to bidirectional pads in pins_if
  logic [NUM_GPIOS-1:0] dut_gpio_o;
  logic [NUM_GPIOS-1:0] dut_gpio_en_o;

  logic [3:0] spi_host_sd;
  logic [3:0] spi_host_sd_en;

  // ------ Interfaces ------
  clk_rst_if sys_clk_if(.clk(clk), .rst_n(rst_n));
  uart_if uart_if();
  pins_if #(NUM_GPIOS) gpio_pins_if (.pins(gpio_pads));

  // ------ Mock DRAM ------
  top_pkg::axi_dram_req_t  dram_req;
  top_pkg::axi_dram_resp_t dram_resp;

  dram_wrapper_sim u_dram_wrapper (
    // Clock and reset.
    .clk_i      (dut.clkmgr_clocks.clk_main_infra),
    .rst_ni     (dut.rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    // AXI interface.
    .axi_req_i  (dram_req                        ),
    .axi_resp_o (dram_resp                       )
  );

  // ------ DUT ------
  top_chip_system #(
    .SramInitFile(""),
    .RomInitFile ("")
  ) dut (
    // Clock and reset.
    .clk_i                (clk              ),
    .rst_ni               (rst_n            ),
    // GPIO inputs and outputs with output enable
    .gpio_i               (gpio_pads        ),
    .gpio_o               (dut_gpio_o       ),
    .gpio_en_o            (dut_gpio_en_o    ),
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
    // SPI host.
    .spi_host_sck_o       (                 ),
    .spi_host_sck_en_o    (                 ),
    .spi_host_csb_o       (                 ),
    .spi_host_csb_en_o    (                 ),
    .spi_host_sd_o        (spi_host_sd      ),
    .spi_host_sd_en_o     (spi_host_sd_en   ),
    // Mapping output 0 to input 1 because legacy SPI does not allow
    // bi-directional wires.
    // This only works in standard mode where sd_o[0]=COPI and
    // sd_i[1]=CIPO.
    .spi_host_sd_i        ({2'b0, spi_host_sd_en[0] ? spi_host_sd[0] : 1'b0, 1'b0}),
    // DRAM.
    .dram_req_o           (dram_req         ),
    .dram_resp_i          (dram_resp        )
  );

  // Assignment to the GPIO pads. If dut_gpio_en_o[i] is disabled, then let the gpio_pad[i] float so
  // an external device / driver can drive it.
  for (genvar i = 0; i < NUM_GPIOS; i++) begin : gen_gpio_pads
    assign gpio_pads[i] = dut_gpio_en_o[i] ? dut_gpio_o[i] : 1'bz;
  end

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
      chip_mem_e     mem;
      mem_bkdr_util  m_mem_bkdr_util[chip_mem_e];
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

      m_mem_bkdr_util[ChipMemROM] = new(
        .name                 ("mem_bkdr_util[ChipMemROM]"        ),
        .path                 (`DV_STRINGIFY(`ROM_MEM_HIER)        ),
        .depth                ($size(`ROM_MEM_HIER)                ),
        .n_bits               ($bits(`ROM_MEM_HIER)                ),
        .err_detection_scheme (mem_bkdr_util_pkg::ErrDetectionNone),
        .system_base_addr     (top_pkg::RomCtrlMemBase             )
      );

      `MEM_BKDR_UTIL_FILE_OP(m_mem_bkdr_util[ChipMemROM], `ROM_MEM_HIER)


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
    `SIM_SRAM_IF.start_addr                              = SW_DV_START_ADDR;
    `SIM_SRAM_IF.sw_dv_size                              = SW_DV_SIZE;
    `SIM_SRAM_IF.u_sw_test_status_if.sw_test_status_addr = SW_DV_TEST_STATUS_ADDR;
    `SIM_SRAM_IF.u_sw_logger_if.sw_log_addr              = SW_DV_LOG_ADDR;

    // Enable GPIO pull-ups to support the SW boot process. While only pin 8 is strictly required
    // by the Boot ROM to determine the boot path, we enable pull-ups on all pins for consistency.
    gpio_pins_if.set_pullup_en('1);

    // Start clock and reset generators
    sys_clk_if.set_active();

    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "sys_clk_if", sys_clk_if);
    uvm_config_db#(virtual uart_if)::set(null, "*.env.m_uart_agent*", "vif", uart_if);
    uvm_config_db#(virtual pins_if #(NUM_GPIOS))::set(null, "*.env", "gpio_vif", gpio_pins_if);

    // SW logger and test status interfaces.
    uvm_config_db#(virtual sw_test_status_if)::set(
        null, "*.env", "sw_test_status_vif", `SIM_SRAM_IF.u_sw_test_status_if);
    uvm_config_db#(virtual sw_logger_if)::set(
        null, "*.env", "sw_logger_vif", `SIM_SRAM_IF.u_sw_logger_if);

    // Run UVM test
    run_test();
  end
endmodule : tb
