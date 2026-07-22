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
  import top_chip_dv_env_pkg::SW_DV_HW_ID_ADDR;
  import top_chip_dv_env_pkg::SW_DV_HW_ID;

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

  // Noise source connections
  logic                                      rng_enable;
  logic                                      rng_valid;
  logic [top_pkg::EntropySrcRngBusWidth-1:0] rng_bits;

  // I2C connections
  wire  scl;
  wire  sda;
  logic scl_en_o;
  logic sda_en_o;
  logic scl_o;
  logic sda_o;

  // ------ Interfaces ------
  clk_rst_if sys_clk_if(.clk(clk), .rst_n(rst_n));
  uart_if uart_if();
  pins_if #(NUM_GPIOS) gpio_pins_if (.pins(gpio_pads));
  i2c_if i2c_if (.clk_i(clk    ),
                 .rst_ni(rst_n ),
                 .scl_io(scl   ),
                 .sda_io(sda   )
                );

  // Passive AXI monitors on each AXI itf of the crossbar
  wire axi_mon_rst_n = dut.rstmgr_resets.rst_main_n[rstmgr_pkg::DomainMainSel];

  // ---- Host (manager) ports ----
  `define AXI_MON_MGR(u_inst, host, agent_name, id_str)             \
    axi_vip_if #(                                                   \
      .req_t     (top_pkg::axi_req_t),                              \
      .resp_t    (top_pkg::axi_resp_t),                             \
      .IdWidth   (top_pkg::AxiIdWidth),                             \
      .AddrWidth (top_pkg::AxiAddrWidth),                           \
      .DataWidth (top_pkg::AxiDataWidth),                           \
      .UserWidth (top_pkg::AxiUserWidth),                           \
      .IsActive  (uvm_pkg::UVM_PASSIVE),                            \
      .InstId    (id_str),                                          \
      .CfgScope  ({"*.", agent_name})                               \
    ) u_inst (.clk_i(clk), .rst_ni(axi_mon_rst_n));                 \
    assign u_inst.axi_req  = `AXI_XBAR_HIER.slv_ports_req_i [host]; \
    assign u_inst.axi_resp = `AXI_XBAR_HIER.slv_ports_resp_o[host]

  // ---- Device (subordinate) ports ----
  `define AXI_MON_SUB(u_inst, dev, agent_name, id_str)              \
    axi_vip_if #(                                                   \
      .req_t     (top_pkg::axi_dev_req_t),                          \
      .resp_t    (top_pkg::axi_dev_resp_t),                         \
      .IdWidth   (top_pkg::AxiDevIdWidth),                          \
      .AddrWidth (top_pkg::AxiAddrWidth),                           \
      .DataWidth (top_pkg::AxiDataWidth),                           \
      .UserWidth (top_pkg::AxiUserWidth),                           \
      .IsActive  (uvm_pkg::UVM_PASSIVE),                            \
      .InstId    (id_str),                                          \
      .CfgScope  ({"*.", agent_name})                               \
    ) u_inst (.clk_i(clk), .rst_ni(axi_mon_rst_n));                 \
    assign u_inst.axi_req  = `AXI_XBAR_HIER.mst_ports_req_o [dev];  \
    assign u_inst.axi_resp = `AXI_XBAR_HIER.mst_ports_resp_i[dev]

  `AXI_MON_MGR(u_axi_mon_cva6,       top_pkg::CVA6,       "m_mgr_axi_CVA6",       "CVA6");
  `AXI_MON_MGR(u_axi_mon_dm_host,    top_pkg::DM_HOST,    "m_mgr_axi_DM_HOST",    "DM_HOST");
  `AXI_MON_SUB(u_axi_mon_romctrlmem, top_pkg::RomCtrlMem, "m_sub_axi_RomCtrlMem", "RomCtrlMem");
  `AXI_MON_SUB(u_axi_mon_sram,       top_pkg::SRAM,       "m_sub_axi_SRAM",       "SRAM");
  `AXI_MON_SUB(u_axi_mon_dm_dev,     top_pkg::DM_DEV,     "m_sub_axi_DM_DEV",     "DM_DEV");
  `AXI_MON_SUB(u_axi_mon_mailbox,    top_pkg::Mailbox,    "m_sub_axi_Mailbox",    "Mailbox");
  `AXI_MON_SUB(u_axi_mon_restofchip, top_pkg::RestOfChip, "m_sub_axi_RestOfChip", "RestOfChip");
  `AXI_MON_SUB(u_axi_mon_tlcrossbar, top_pkg::TlCrossbar, "m_sub_axi_TlCrossbar", "TlCrossbar");
  `AXI_MON_SUB(u_axi_mon_dram,       top_pkg::DRAM,       "m_sub_axi_DRAM",       "DRAM");

  `undef AXI_MON_MGR
  `undef AXI_MON_SUB

  // ------ Mock DRAM ------
  top_pkg::axi_dram_req_t  dram_req;
  top_pkg::axi_dram_resp_t dram_resp;

  // ------ SW-DV window ------
  top_pkg::axi_dev_req_t  sw_dv_req;
  top_pkg::axi_dev_resp_t sw_dv_resp;

  dram_wrapper_sim u_dram_wrapper (
    // Clock and reset.
    .clk_i      (dut.clkmgr_clocks.clk_main_infra),
    .rst_ni     (dut.rstmgr_resets.rst_main_n[rstmgr_pkg::DomainMainSel]),
    // AXI interface.
    .axi_req_i  (dram_req                        ),
    .axi_resp_o (dram_resp                       )
  );

  // ------ Noise source ------
  rng u_rng(
    .clk_i  (dut.clkmgr_clocks.clk_io_infra),
    .rst_ni (dut.rstmgr_resets.rst_io_n[rstmgr_pkg::DomainMainSel]),

    // Entropy output bus
    .rng_enable_i (rng_enable),
    .rng_valid_o  (rng_valid),
    .rng_bits_o   (rng_bits)
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
    // I2C controller/target bidirectional interface.
    .i2c_scl_i            (scl              ),
    .i2c_scl_o            (scl_o            ),
    .i2c_scl_en_o         (scl_en_o         ),
    .i2c_sda_i            (sda              ),
    .i2c_sda_o            (sda_o            ),
    .i2c_sda_en_o         (sda_en_o         ),
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
    // Entropy source.
    .entropy_src_rng_enable_o (rng_enable   ),
    .entropy_src_rng_valid_i  (rng_valid    ),
    .entropy_src_rng_bits_i   (rng_bits     ),
    // DRAM.
    .dram_req_o           (dram_req         ),
    .dram_resp_i          (dram_resp        ),
    // SW-DV window AXI.
    .sw_dv_req_o          (sw_dv_req        ),
    .sw_dv_resp_i         (sw_dv_resp       ),
    // Rest of chip AXI tie-off.
    .rest_of_chip_req_o   (                 ),
    .rest_of_chip_resp_i  ('0               ),
    // Ethernet interrupt in tie-off.
    .ethernet_irq_i       ('0               ),
    // Debug module JTAG tie-off.
    .dm_jtag_tck          (1'b0             ),
    .dm_jtag_tms          (1'b0             ),
    .dm_jtag_tdi          (1'b0             ),
    .dm_jtag_tdo          (                 ),
    .dm_jtag_trst_n       (1'b0             )
  );

  // Assignment to the GPIO pads. If dut_gpio_en_o[i] is disabled, then let the gpio_pad[i] float so
  // an external device / driver can drive it.
  for (genvar i = 0; i < NUM_GPIOS; i++) begin : gen_gpio_pads
    assign gpio_pads[i] = dut_gpio_en_o[i] ? dut_gpio_o[i] : 1'bz;
  end

  // Modelling the open-drain circuit
  assign (strong0, weak1) scl = (scl_en_o) ? scl_o : 1'b1;
  assign (strong0, weak1) sda = (sda_en_o) ? sda_o : 1'b1;

  // SW-DV sink: receives only SW-DV window traffic from the crossbar.
  sim_sram_axi_sink u_sim_sram (
    .clk_i      (dut.clkmgr_clocks.clk_main_infra                       ),
    .rst_ni     (dut.rstmgr_resets.rst_main_n[rstmgr_pkg::DomainMainSel]),
    .axi_req_i  (sw_dv_req                                              ),
    .axi_resp_o (sw_dv_resp                                             )
  );

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
    `SIM_SRAM_IF.hw_id                                   = SW_DV_HW_ID;
    `SIM_SRAM_IF.hw_id_addr                              = SW_DV_HW_ID_ADDR;
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
    uvm_config_db#(virtual i2c_if)::set(null, "*.env.m_i2c_agent", "vif", i2c_if);

    // SW logger and test status interfaces.
    uvm_config_db#(virtual sw_test_status_if)::set(
        null, "*.env", "sw_test_status_vif", `SIM_SRAM_IF.u_sw_test_status_if);
    uvm_config_db#(virtual sw_logger_if)::set(
        null, "*.env", "sw_logger_vif", `SIM_SRAM_IF.u_sw_logger_if);

    // Run UVM test
    run_test();
  end
endmodule : tb
