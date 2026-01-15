// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module chip_mocha_genesys2 #(
  parameter BootRomInitFile = ""
) (
  // Onboard 200MHz oscillator
  input  logic sysclk_200m_ni,
  input  logic sysclk_200m_pi,

  // External reset
  input  logic ext_rst_ni,

  // UART
  input  logic uart_rx_i,
  output logic uart_tx_o,

  // SPI
  input  logic spi_device_sck_i,
  input  logic spi_device_csb_i,
  input  logic spi_device_sd_i,
  output logic spi_device_sd_o
);
  // Internal clock and reset signals
  logic clk_50m;
  logic rst_n;

  // PLL lock signal
  logic pll_locked;

  // QSPI signals
  logic [3:0] qspi_device_sdo;
  logic [3:0] qspi_device_sdo_en;

  // Clock generation
  clkgen_xil7series clk_gen(
    .clk_200m_ni (sysclk_200m_ni),
    .clk_200m_pi (sysclk_200m_pi),
    .pll_locked_o(pll_locked),
    .clk_50m_o   (clk_50m)
  );

  // Internal reset generation
  assign rst_n = pll_locked & ext_rst_ni;

  // CHERI Mocha top
  top_chip_system #(
    .SramInitFile(BootRomInitFile)
  ) u_top_chip_system (
    // Clock and reset
    .clk_i    (clk_50m),
    .rst_ni   (rst_n),
    // UART
    .uart_rx_i,
    .uart_tx_o,

    .spi_device_sck_i     (spi_device_sck_i),
    .spi_device_csb_i     (spi_device_csb_i),
    .spi_device_sd_o      (qspi_device_sdo),
    .spi_device_sd_en_o   (qspi_device_sdo_en),
    .spi_device_sd_i      ({3'h0, spi_device_sd_i}), // SPI MOSI = QSPI DQ0
    .spi_device_tpm_csb_i ('0)
  );

  // SPI tri-state output driver
  OBUFT spi_obuft (
    .I(qspi_device_sdo[1]),     // SPI MISO = QSPI DQ1
    .T(~qspi_device_sdo_en[1]), // SPI MISO = QSPI DQ1
    .O(spi_device_sd_o)
  );

endmodule
