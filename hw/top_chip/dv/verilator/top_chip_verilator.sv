// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_chip_verilator (
  input logic clk_i,
  input logic rst_ni
);
  // GPIO signals
  logic [31:0] gpio_inputs;
  logic [31:0] gpio_outputs;
  logic [31:0] gpio_en_outputs;

  // I^2C signals
  // Output and output enable clock and data from system.
  logic i2c_scl_sys_o, i2c_scl_sys_oe;
  logic i2c_sda_sys_o, i2c_sda_sys_oe;
  // Output clock and data to the I^2C bus.
  wire i2c_scl_sys_out = i2c_scl_sys_oe ? i2c_scl_sys_o : 1'b1;
  wire i2c_sda_sys_out = i2c_sda_sys_oe ? i2c_sda_sys_o : 1'b1;
  // Clock and data from the I2C DPI model.
  wire i2c_scl_dpi, i2c_sda_dpi;
  // Input clock and data from the I^2C bus; these signals must reflect the physical I^2C bus,
  // ie. they carry both the outbound and the inbound activity, because otherwise the controller
  // will perceive a mismatch between its own transmissions and the inputs as bus contention.
  wire i2c_scl_sys_in = i2c_scl_sys_out & i2c_scl_dpi;
  wire i2c_sda_sys_in = i2c_sda_sys_out & i2c_sda_dpi;

  // UART signals
  logic uart_rx;
  logic uart_tx;

  // SPI signals
  logic       spi_device_sck;
  logic       spi_device_csb;
  logic [3:0] qspi_device_sdo;
  logic [3:0] qspi_device_sdo_en;
  logic       spi_device_sdi;

  // AXI signals
  top_pkg::axi_dram_req_t  dram_req;
  top_pkg::axi_dram_resp_t dram_resp;

  logic [3:0] spi_host_sd;
  logic [3:0] spi_host_sd_en;

  // CHERI Mocha top
  top_chip_system #(
    .SramInitFile(""),
    .RomInitFile ("")
  ) u_top_chip_system (
    .clk_i,
    .rst_ni,

    .gpio_i    (gpio_inputs),
    .gpio_o    (gpio_outputs),
    .gpio_en_o (gpio_en_outputs),

    .uart_rx_i (uart_rx),
    .uart_tx_o (uart_tx),

    .axi_mailbox_req_i   ('0),
    .axi_mailbox_resp_o  ( ),
    .mailbox_ext_irq_o   ( ),

    .i2c_scl_i    (i2c_scl_sys_in),
    .i2c_scl_o    (i2c_scl_sys_o),
    .i2c_scl_en_o (i2c_scl_sys_oe),
    .i2c_sda_i    (i2c_sda_sys_in),
    .i2c_sda_o    (i2c_sda_sys_o),
    .i2c_sda_en_o (i2c_sda_sys_oe),

    .spi_device_sck_i     (spi_device_sck),
    .spi_device_csb_i     (spi_device_csb),
    .spi_device_sd_o      (qspi_device_sdo),
    .spi_device_sd_en_o   (qspi_device_sdo_en),
    .spi_device_sd_i      ({3'h0, spi_device_sdi}), // SPI MOSI = QSPI DQ0
    .spi_device_tpm_csb_i ('0),

    .spi_host_sck_o    ( ),
    .spi_host_sck_en_o ( ),
    .spi_host_csb_o    ( ),
    .spi_host_csb_en_o ( ),
    .spi_host_sd_o     (spi_host_sd),
    .spi_host_sd_en_o  (spi_host_sd_en),
    // Mapping output 0 to input 1 because legacy SPI does not allow
    // bi-directional wires.
    // This only works in standard mode where sd_o[0]=COPI and
    // sd_i[1]=CIPO.
    .spi_host_sd_i     ({2'b0, spi_host_sd_en[0] ? spi_host_sd[0] : 1'b0, 1'b0}),

    .dram_req_o  (dram_req),
    .dram_resp_i (dram_resp),

    .rest_of_chip_req_o  ( ), // Rest of chip AXI tie-off
    .rest_of_chip_resp_i ('0),

    .ethernet_irq_i ('0) // Ethernet interrupt in tie-off.
  );

  // No support for dual or quad SPI in loopback mode right now.
  logic unused_spi_host = (|spi_host_sd[3:2]) | spi_host_sd[0] |
                          (|spi_host_sd_en[3:2]) | spi_host_sd_en[0];

  // Virtual GPIO
  gpiodpi #(
    .N_GPIO(32)
  ) u_gpiodpi (
    .clk_i,
    .rst_ni,
    .active        (1'b1),
    .gpio_p2d      (gpio_inputs),
    .gpio_d2p      (gpio_outputs),
    .gpio_en_d2p   (gpio_en_outputs),
    .gpio_pull_en  (32'hFFFF_FFFF), // pull-ups for all GPIOs
    .gpio_pull_sel (32'hFFFF_FFFF)  // pull-ups for all GPIOs
  );

  // I2C DPI - model an AS621x temperature sensor
  i2cdpi #(
    .ID ("i2c1")  // "i2c1" selects AS621x model
  ) u_i2cdpi (
    // Use clock-synchronised reset to avoid observing false-high signals near the start of time
    .rst_ni  (u_top_chip_system.u_i2c.rst_ni),
    // The connected signal names are from the perspective of the controller.
    .scl_i   (i2c_scl_sys_out),
    .sda_i   (i2c_sda_sys_out),
    .scl_o   (i2c_scl_dpi),
    .sda_o   (i2c_sda_dpi),
    // Out-Of-Band data.
    .oob_in  ('0),
    .oob_out ( )  // not used
  );

  // Virtual UART
  uartdpi #(
    .BAUD        ( 1_000_000                                                   ),
    .FREQ        ( 50_000_000                                                ),
    .EXIT_STRING ( "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7" )
  ) u_uartdpi (
    .clk_i,
    .rst_ni,
    .active(1'b1),
    .tx_o  (uart_rx),
    .rx_i  (uart_tx)
  );

  // Virtual SPI host
  spidpi u_spidpi (
    .clk_i,
    .rst_ni,
    .spi_device_sck_o   (spi_device_sck),
    .spi_device_csb_o   (spi_device_csb),
    .spi_device_sdi_o   (spi_device_sdi),
    .spi_device_sdo_i   (qspi_device_sdo[1]),   // SPI MISO = QSPI DQ1
    .spi_device_sdo_en_i(qspi_device_sdo_en[1]) // SPI MISO = QSPI DQ1
  );

  `define DUT               u_top_chip_system
  `define SIM_SRAM_IF       u_sim_sram.u_sim_sram_if

  localparam bit [31:0] VERILATOR_SW_DV_START_ADDR       = 'h2002_0000;
  localparam bit [31:0] VERILATOR_SW_DV_SIZE             = 'h0000_0100;   // 256 bytes reserved
  localparam bit [31:0] VERILATOR_SW_DV_TEST_STATUS_ADDR = VERILATOR_SW_DV_START_ADDR + 'h00;

  // Signals to connect the sink
  top_pkg::axi_req_t  sim_sram_cpu_req;
  top_pkg::axi_resp_t sim_sram_cpu_resp;
  top_pkg::axi_req_t  sim_sram_xbar_req;
  top_pkg::axi_resp_t sim_sram_xbar_resp;

  // Detect SW test termination.
  sim_sram_axi_sink u_sim_sram (
    .clk_i       (`DUT.clkmgr_clocks.clk_main_infra),
    .rst_ni      (`DUT.rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .cpu_req_i   (sim_sram_cpu_req                 ),
    .cpu_resp_o  (sim_sram_cpu_resp                ),
    .xbar_req_o  (sim_sram_xbar_req                ),
    .xbar_resp_i (sim_sram_xbar_resp               )
  );

  // Connect the sim SRAM directly at CVA6 AXI interface
  assign `DUT.sim_to_cva6_resp = sim_sram_cpu_resp;
  // Drive the request back into the DUT's Crossbar
  assign `DUT.xbar_host_req[top_pkg::CVA6] = sim_sram_xbar_req;

  // Capture inputs FROM the DUT (Monitoring)
  assign sim_sram_cpu_req   = `DUT.cva6_to_sim_req;
  assign sim_sram_xbar_resp = `DUT.xbar_host_resp[top_pkg::CVA6];

  // Instantiate the SW test status interface & connect signals from sim_sram_if instance
  // instantiated inside sim_sram. Bind would have worked nicely here, but Verilator segfaults
  // when trace is enabled (#3951).
  sw_test_status_if u_sw_test_status_if (
    .clk_i    (`SIM_SRAM_IF.clk_i            ),
    .rst_ni   (`SIM_SRAM_IF.rst_ni           ),
    .fetch_en (1'b0                          ),
    .wr_valid (`SIM_SRAM_IF.wr_valid         ),
    .addr     (`SIM_SRAM_IF.req.aw.addr[31:0]), // Only lower 32-bits is enough
    .data     (`SIM_SRAM_IF.req.w.data[15:0] )  // Test status is 16-bits wide
  );

  // Set the start address and the size of the simulation SRAM
  initial begin
    `SIM_SRAM_IF.start_addr                 = VERILATOR_SW_DV_START_ADDR;
    `SIM_SRAM_IF.sw_dv_size                 = VERILATOR_SW_DV_SIZE;
    u_sw_test_status_if.sw_test_status_addr = VERILATOR_SW_DV_TEST_STATUS_ADDR;
  end

  always @(posedge `SIM_SRAM_IF.clk_i) begin
    if (u_sw_test_status_if.sw_test_done) begin
      $display("Verilator sim termination requested");
      $display("Your simulation wrote to 0x%h", u_sw_test_status_if.sw_test_status_addr);
      dv_test_status_pkg::dv_test_status(u_sw_test_status_if.sw_test_passed);
      $finish;
    end
  end

  `undef DUT
  `undef SIM_SRAM_IF

  // Mock AXI external memory
  dram_wrapper_sim u_dram_wrapper(
    .clk_i  (u_top_chip_system.clkmgr_clocks.clk_main_infra),
    .rst_ni (u_top_chip_system.rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

    // AXI interface
    .axi_req_i  (dram_req),
    .axi_resp_o (dram_resp)
  );
endmodule
