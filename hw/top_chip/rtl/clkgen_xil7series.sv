// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module clkgen_xil7series (
  input  logic clk_200m_ni,
  input  logic clk_200m_pi,
  output logic pll_locked_o,
  output logic clk_50m_o
);
  // Internal signals
  logic clk_200m_buf;
  logic clk_fb_int;
  logic clk_50m_unbuf;

  // Input buffering
  IBUFDS clk_200m_ibufds_inst(
    .I (clk_200m_pi),
    .IB(clk_200m_ni),
    .O (clk_200m_buf)
  );

  // PLL
  MMCME2_ADV #(
    .BANDWIDTH            ("OPTIMIZED"),
    .CLKOUT4_CASCADE      ("FALSE"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .CLKIN1_PERIOD        (5.000),  // f_CLKIN = 200 MHz
    .DIVCLK_DIVIDE        (1),      // f_PFD = 200 MHz
    .CLKFBOUT_MULT_F      (5.000),  // f_VCO = 1000 MHz
    .CLKFBOUT_PHASE       (0.000),
    .CLKFBOUT_USE_FINE_PS ("FALSE"),
    .CLKOUT0_DIVIDE_F     (20.000), // f_CLKOUT0 = 50 MHz
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKOUT0_USE_FINE_PS  ("FALSE")
  ) pll (
    .CLKFBOUT            (clk_fb_int),
    .CLKFBOUTB           (),
    .CLKOUT0             (clk_50m_unbuf),
    .CLKOUT0B            (),
    .CLKOUT1             (),
    .CLKOUT1B            (),
    .CLKOUT2             (),
    .CLKOUT2B            (),
    .CLKOUT3             (),
    .CLKOUT3B            (),
    .CLKOUT4             (),
    .CLKOUT5             (),
    .CLKOUT6             (),
    // Input clock control
    .CLKFBIN             (clk_fb_int),
    .CLKIN1              (clk_200m_buf),
    .CLKIN2              (1'b0),
    // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (),
    .DRDY                (),
    .DWE                 (1'b0),
    // Ports for dynamic phase shift
    .PSCLK               (1'b0),
    .PSEN                (1'b0),
    .PSINCDEC            (1'b0),
    .PSDONE              (),
    // Other control and status signals
    .LOCKED              (pll_locked_o),
    .CLKINSTOPPED        (),
    .CLKFBSTOPPED        (),
    .PWRDWN              (1'b0),
    .RST                 (1'b0)
  );

  // Output buffering
  BUFG clk_50m_bufg_inst(
    .I(clk_50m_unbuf),
    .O(clk_50m_o)
  );

endmodule
