// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wrapper around prim_fifo_sync that mimicks Pulp's stream_fifo
module stream_fifo #(
  parameter bit FALL_THROUGH = 1'b0,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned DEPTH = 8,
  parameter type T = logic [DATA_WIDTH-1:0],
  // DO NOT OVERWRITE THIS PARAMETER
  parameter int unsigned ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input  logic                  clk_i,
  input  logic                  rst_ni,
  input  logic                  flush_i,
  input  logic                  testmode_i,
  output logic [ADDR_DEPTH-1:0] usage_o,
  input  T                      data_i,
  input  logic                  valid_i,
  output logic                  ready_o,
  output T                      data_o,
  output logic                  valid_o,
  input  logic                  ready_i
);
  logic unused_testmode;
  logic unused_full;
  logic unused_err;
  // Usage must be able to express DEPTH to indicate full.
  logic [prim_util_pkg::vbits(DEPTH+1)-1:0] usage;

  // Use prim_fifo_sync's own valid/ready rather than deriving them from the
  // occupancy (as fifo_v3 does), so that FALL_THROUGH passes data through an
  // empty FIFO in the same cycle.
  prim_fifo_sync #(
    .Width             ( $bits(T)     ),
    .Pass              ( FALL_THROUGH ),
    .Depth             ( DEPTH        ),
    .OutputZeroIfEmpty ( 1'b0         ),
    .NeverClears       ( 1'b0         ),
    .Secure            ( 1'b0         )
  ) u_prim_fifo_sync (
    .clk_i    (clk_i),
    .rst_ni   (rst_ni),
    .clr_i    (flush_i),
    .wvalid_i (valid_i),
    .wready_o (ready_o),
    .wdata_i  (data_i),
    .rvalid_o (valid_o),
    .rready_i (ready_i),
    .rdata_o  (data_o),
    .full_o   (unused_full),
    .depth_o  (usage),
    .err_o    (unused_err)
  );

  // When DEPTH is a power of two usage_o is zero when full, as in Pulp's FIFOs.
  assign usage_o = ADDR_DEPTH'(usage);

  assign unused_testmode = testmode_i;
endmodule
