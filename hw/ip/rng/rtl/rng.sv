// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module rng (
  // Clock and reset
  input  logic clk_i,
  input  logic rst_ni,

  // Noise source output
  input  logic                                      rng_enable_i,
  output logic                                      rng_valid_o,
  output logic [top_pkg::EntropySrcRngBusWidth-1:0] rng_bits_o
);
  // Local parameters
  localparam int RateDivide = 6;  // Limit noise source output rate to 1 strobe every RateDivide cycles

  // These LFSR parameters have been generated with
  // $ ./util/design/gen-lfsr-seed.py --width 64 --seed 24707 --prefix "Rng"
  parameter int RngLfsrWidth = 64;
  typedef logic [RngLfsrWidth-1:0] rng_lfsr_seed_t;
  typedef logic [RngLfsrWidth-1:0][$clog2(RngLfsrWidth)-1:0] rng_lfsr_perm_t;
  parameter rng_lfsr_seed_t RndCnstRngLfsrSeedDefault = {
    64'hcf5a4868_25ad321b
  };
  parameter rng_lfsr_perm_t RndCnstRngLfsrPermDefault = {
    128'h5542c6aa_de3f31ab_8e92988f_06677181,
    256'h1edede70_d86e336c_e75a1fad_940ac3e7_16017bc5_1c2cf627_cf6523a4_93132874
  };

  // Internal reset signal
  logic rst_n;

  // LFSR output signal
  logic [top_pkg::EntropySrcRngBusWidth-1:0] lfsr_val;

  // Rate control counter register
  logic [$clog2(RateDivide-1)-1:0] rate_ctr;

  // Internal reset generation
  assign rst_n = rst_ni && rng_enable_i;

  // Instantiate LFSR
  prim_lfsr #(
    .LfsrDw      ( RngLfsrWidth                   ),
    .EntropyDw   ( 1                              ),
    .StateOutDw  ( top_pkg::EntropySrcRngBusWidth ),
    .DefaultSeed ( RndCnstRngLfsrSeedDefault      ),
    .StatePermEn ( 1'b1                           ),
    .StatePerm   ( RndCnstRngLfsrPermDefault      ),
    .ExtSeedSVA  ( 1'b0                           )
  ) u_rng_lfsr (
    .clk_i     (clk_i),
    .rst_ni    (rst_n),
    .lfsr_en_i (rng_enable_i),
    .seed_en_i (1'b0),
    .seed_i    ('0),
    .entropy_i (1'b0),
    .state_o   (lfsr_val)
  );

  // Rate control counter logic
  always_ff @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
      rate_ctr <= '0;
    end else if (rate_ctr == $clog2(RateDivide - 1)'(RateDivide - 1)) begin
      rate_ctr <= '0;
    end else begin
      rate_ctr <= rate_ctr + 1;
    end
  end

  // Noise output generation
  always_ff @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) rng_valid_o <= 0;
    else        rng_valid_o <= (rate_ctr == $clog2(RateDivide - 1)'(RateDivide - 1));
  end

  always_ff @(posedge clk_i or negedge rst_n) begin
    if (!rst_n) begin
      rng_bits_o <= '0;
    end else if (rate_ctr == $clog2(RateDivide - 1)'(RateDivide - 1)) begin
      rng_bits_o <= lfsr_val[top_pkg::EntropySrcRngBusWidth-1:0];
    end
  end
endmodule
