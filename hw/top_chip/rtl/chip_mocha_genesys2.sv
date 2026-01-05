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
  output logic uart_tx_o
);
  // Internal clock and reset signals
  logic clk_50m;
  logic rst_n;

  // PLL lock signal
  logic pll_locked;

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
    .uart_tx_o
  );

endmodule
