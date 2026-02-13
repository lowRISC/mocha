// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_chip_verilator (input logic clk_i, rst_ni);
  // UART signals
  logic uart_rx;
  logic uart_tx;

  // SPI signals
  logic       spi_device_sck;
  logic       spi_device_csb;
  logic [3:0] qspi_device_sdo;
  logic [3:0] qspi_device_sdo_en;
  logic       spi_device_sdi;

  // CHERI Mocha top
  top_chip_system #(
  ) u_top_chip_system (
    .clk_i,
    .rst_ni,

    .uart_rx_i (uart_rx),
    .uart_tx_o (uart_tx),

    .spi_device_sck_i     (spi_device_sck),
    .spi_device_csb_i     (spi_device_csb),
    .spi_device_sd_o      (qspi_device_sdo),
    .spi_device_sd_en_o   (qspi_device_sdo_en),
    .spi_device_sd_i      ({3'h0, spi_device_sdi}), // SPI MOSI = QSPI DQ0
    .spi_device_tpm_csb_i ('0)
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

  localparam bit [31:0] VERILATOR_SW_DV_START_ADDR       = 'h2001_0000;
  localparam bit [31:0] VERILATOR_SW_DV_SIZE             = 'h0000_0100;   // 256 bytes reserved
  localparam bit [31:0] VERILATOR_SW_DV_TEST_STATUS_ADDR = VERILATOR_SW_DV_START_ADDR + 'h00;

  // Signals to connect the sink
  top_pkg::axi_req_t  sim_sram_cpu_req;
  top_pkg::axi_resp_t sim_sram_cpu_resp;
  top_pkg::axi_req_t  sim_sram_xbar_req;
  top_pkg::axi_resp_t sim_sram_xbar_resp;

  // Detect SW test termination.
  sim_sram_axi_sink u_sim_sram (
    .clk_i          (`DUT.clk_i         ),
    .rst_ni         (`DUT.rst_ni        ),
    .cpu_req_i      (sim_sram_cpu_req   ),
    .cpu_resp_o     (sim_sram_cpu_resp  ),
    .xbar_req_o     (sim_sram_xbar_req  ),
    .xbar_resp_i    (sim_sram_xbar_resp )
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

  always @(posedge clk_i) begin
    if (u_sw_test_status_if.sw_test_done) begin
      $display("Verilator sim termination requested");
      $display("Your simulation wrote to 0x%h", u_sw_test_status_if.sw_test_status_addr);
      dv_test_status_pkg::dv_test_status(u_sw_test_status_if.sw_test_passed);
      $finish;
    end
  end

  `undef DUT
  `undef SIM_SRAM_IF
endmodule
