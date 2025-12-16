// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module chip_mocha_genesys2 #(
  parameter BootRomInitFile = ""
) (
  // Onboard 200MHz oscillator
  input  logic sysclk_200m_ni,
  input  logic sysclk_200m_pi,

  // UART
  input  logic uart_rx_i,
  output logic uart_tx_o
);
  // Local parameters
  localparam int ResetCycles = 3;

  // Internal clock and reset signals
  logic clk_50m;
  logic rst_n;

  // PLL lock signal
  logic pll_locked;

  // Reset generation shift register
  logic [ResetCycles-1:0] rst_n_shreg;

  // Clock generation
  clkgen_xil7series clk_gen(
    .clk_200m_ni (sysclk_200m_ni),
    .clk_200m_pi (sysclk_200m_pi),
    .pll_locked_o(pll_locked),
    .clk_50m_o   (clk_50m)
  );

  // Reset pulse generation
  always_ff @(posedge clk_50m or negedge pll_locked) begin
    if (!pll_locked) begin
      rst_n_shreg <= '0;
    end else begin
      rst_n_shreg <= {1'b1, rst_n_shreg[ResetCycles-1:1]};
    end
  end

  assign rst_n = rst_n_shreg[0];

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
