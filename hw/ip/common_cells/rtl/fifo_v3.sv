// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Wrapper around prim_fifo_sync that mimicks Pulp's fifo_v3
module fifo_v3 #(
  parameter bit FALL_THROUGH = 0,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned DEPTH = 8,
  parameter type dtype = logic [DATA_WIDTH-1:0],
  // DO NOT OVERWRITE THIS PARAMETER
  parameter int unsigned ADDR_DEPTH = (DEPTH > 1) ? $clog2(DEPTH) : 1
) (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic flush_i,
  input  logic testmode_i,
  output logic full_o,
  output logic empty_o,
  output logic [ADDR_DEPTH-1:0] usage_o,
  input  dtype data_i,
  input  logic push_i,
  output dtype data_o,
  input  logic pop_i
);
  logic unused_testmode;
  logic wready;
  logic unused_rvalid;
  logic full;
  // Usage must be able to express DEPTH to indicate full.
  logic [prim_util_pkg::vbits(DEPTH+1)-1:0] usage;
  logic err;

  prim_fifo_sync #(
    .Width             ( $bits(dtype) ),
    .Pass              ( FALL_THROUGH ),
    .Depth             ( DEPTH        ),
    .OutputZeroIfEmpty ( 1            ),
    .NeverClears       ( 0            ),
    .Secure            ( 0            )
  ) u_prim_fifo_sync (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .clr_i    (flush_i),
    .wvalid_i (push_i),
    .wready_o (wready),
    .wdata_i  (data_i),
    .rvalid_o (unused_rvalid),
    .rready_i (pop_i),
    .rdata_o  (data_o),
    .full_o   (full),
    .depth_o  (usage),
    .err_o    (err)
  );

  assign full_o  = full | err | ~wready;
  assign empty_o = ((usage == '0) & ~full) | err;
  // When DEPTH is a power of two usage_o is zero when full.
  // Otherwise usage_o is equal to DEPTH when full.
  assign usage_o = ADDR_DEPTH'(usage);

  assign unused_testmode = testmode_i;
endmodule
