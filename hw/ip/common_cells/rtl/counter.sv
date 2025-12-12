// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// OpenTitan primitive wrapper for the Pulp single increment counter.

module counter #(
    parameter int unsigned WIDTH = 4,
    parameter bit STICKY_OVERFLOW = 1'b0
)(
    input  logic             clk_i,
    input  logic             rst_ni,
    input  logic             clear_i,
    input  logic             en_i,
    input  logic             load_i,
    input  logic             down_i,
    input  logic [WIDTH-1:0] d_i,
    output logic [WIDTH-1:0] q_o,
    output logic             overflow_o
);
  prim_count #(
    .Width ( WIDTH )
  ) u_prim_count (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .clr_i              (clear_i),
    .set_i              (load_i),
    .set_cnt_i          (d_i),
    .incr_en_i          (en_i & ~down_i),
    .decr_en_i          (en_i & down_i),
    .step_i             ({{WIDTH-1{1'b0}}, 1'b1}),
    .commit_i           (1'b1),
    .cnt_o              (q_o),
    .cnt_after_commit_o ( ),
    .err_o              (overflow_o)
  );
endmodule
