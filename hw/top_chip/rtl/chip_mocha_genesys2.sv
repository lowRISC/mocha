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

  // GPIO - enough for the user switches and LEDs as a starting point
  input  logic [7:0] gpio_i,
  output logic [7:0] gpio_o,

  // UART
  input  logic uart_rx_i,
  output logic uart_tx_o,

  // SPI
  input  logic spi_device_sck_i,
  input  logic spi_device_csb_i,
  input  logic spi_device_sd_i,
  output logic spi_device_sd_o,
  output logic spien
);
  // Internal clock and reset signals
  logic clk_50m;
  logic rst_n;

  // PLL lock signal
  logic pll_locked;

  // Output buffer value+enable signals
  logic [31:0] gpio_outputs;
  logic [31:0] gpio_en_outputs;
  logic [3:0]  qspi_device_sdo;
  logic [3:0]  qspi_device_sdo_en;

  // Clock generation
  clkgen_xil7series clk_gen(
    .clk_200m_ni (sysclk_200m_ni),
    .clk_200m_pi (sysclk_200m_pi),
    .pll_locked_o(pll_locked),
    .clk_50m_o   (clk_50m)
  );

  assign spien = 1;
  // Internal reset generation
  assign rst_n = pll_locked & ext_rst_ni;

  // CHERI Mocha top
  top_chip_system #(
    .SramInitFile(BootRomInitFile)
  ) u_top_chip_system (
    // Clock and reset
    .clk_i    (clk_50m),
    .rst_ni   (rst_n),

    // GPIO
    .gpio_i    ({24'd0, gpio_i}),
    .gpio_o    (gpio_outputs),
    .gpio_en_o (gpio_en_outputs),

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

  // GPIO tri-state output drivers
  // Instantiate for only the outputs connected to an FPGA pin
  for (genvar ii = 0; ii < 8; ii++) begin : gen_gpio_o
    OBUFT obuft (
      .I(gpio_outputs[ii]),
      .T(~gpio_en_outputs[ii]),
      .O(gpio_o[ii])
    );
  end

  // SPI tri-state output driver
  OBUFT spi_obuft (
    .I(qspi_device_sdo[1]),     // SPI MISO = QSPI DQ1
    .T(~qspi_device_sdo_en[1]), // SPI MISO = QSPI DQ1
    .O(spi_device_sd_o)
  );

endmodule
