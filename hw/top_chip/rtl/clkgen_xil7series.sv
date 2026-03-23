// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module clkgen_xil7series (
  input  logic clk_200m_i,
  output logic clk_cfg_o,
  output logic pll_locked_o,
  output logic clk_50m_o,
  output logic clk_125m_o,
  output logic clk_125m_quad_o
);
  // Internal signals
  logic clk_fb_unbuf;
  logic clk_fb_buf;
  logic clk_50m_unbuf;
  logic clk_125m_unbuf;
  logic clk_125m_quad_unbuf;
  logic clk_cfg_unbuf;

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
    .CLKOUT0_USE_FINE_PS  ("FALSE"),
    .CLKOUT1_DIVIDE       (8),      // f_CLKOUT1 = 125 MHz
    .CLKOUT1_PHASE        (0.000),
    .CLKOUT1_DUTY_CYCLE   (0.500),
    .CLKOUT1_USE_FINE_PS  ("FALSE"),
    .CLKOUT2_DIVIDE       (8),      // f_CLKOUT2 = 125 MHz
    .CLKOUT2_PHASE        (90.000), // Quadrature (90 deg phase shift)
    .CLKOUT2_DUTY_CYCLE   (0.500),
    .CLKOUT2_USE_FINE_PS  ("FALSE")
  ) pll (
    .CLKFBOUT            (clk_fb_unbuf),
    .CLKFBOUTB           (),
    .CLKOUT0             (clk_50m_unbuf),
    .CLKOUT0B            (),
    .CLKOUT1             (clk_125m_unbuf),
    .CLKOUT1B            (),
    .CLKOUT2             (clk_125m_quad_unbuf),
    .CLKOUT2B            (),
    .CLKOUT3             (),
    .CLKOUT3B            (),
    .CLKOUT4             (),
    .CLKOUT5             (),
    .CLKOUT6             (),
    // Input clock control
    .CLKFBIN             (clk_fb_buf),
    .CLKIN1              (clk_200m_i),
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

  // Feedback clock buffering
  BUFG clk_fb_bufg_inst (
    .I(clk_fb_unbuf),
    .O(clk_fb_buf)
  );

  // Get free-running clock from configuration logic
  STARTUPE2 STARTUPE2_inst (
    .CFGCLK    ( ),             // 1-bit output: Configuration main clock output
    .CFGMCLK   (clk_cfg_unbuf), // 1-bit output: Configuration internal oscillator clock output
    .EOS       ( ),             // 1-bit output: Active high output signal indicating the End Of Startup
    .PREQ      ( ),             // 1-bit output: PROGRAM request to fabric output
    .CLK       ('0),            // 1-bit input: User start-up clock input
    .GSR       ('0),            // 1-bit input: Global Set/Reset input
    .GTS       ('0),            // 1-bit input: Global 3-state input
    .KEYCLEARB ('0),            // 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
    .PACK      ('0),            // 1-bit input: PROGRAM acknowledge input
    .USRCCLKO  ('0),            // 1-bit input: User CCLK input
    .USRCCLKTS ('0),            // 1-bit input: User CCLK 3-state enable input
    .USRDONEO  (1'b1),          // 1-bit input: User DONE pin output control
    .USRDONETS (1'b1)           // 1-bit input: User DONE 3-state enable output
  );

  // Output buffering
  BUFG clk_50m_bufg_inst (
    .I(clk_50m_unbuf),
    .O(clk_50m_o)
  );

  BUFG clk_125m_bufg_inst (
    .I(clk_125m_unbuf),
    .O(clk_125m_o)
  );

  BUFG clk_125m_quad_bufg_inst (
    .I(clk_125m_quad_unbuf),
    .O(clk_125m_quad_o)
  );

  BUFG clk_cfg_bufg_inst (
    .I(clk_cfg_unbuf),
    .O(clk_cfg_o)
  );

endmodule
