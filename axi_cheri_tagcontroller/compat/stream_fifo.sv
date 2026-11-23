// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// common_cells' stream_fifo, which Mocha's common_cells subset leaves out: a valid/ready FIFO of
// DEPTH entries that, with FALL_THROUGH, passes data straight through while empty.

module stream_fifo #(
  parameter bit          FALL_THROUGH = 1'b0,
  parameter int unsigned DATA_WIDTH   = 32,
  parameter int unsigned DEPTH        = 8,
  parameter type         T            = logic [DATA_WIDTH-1:0],
  parameter int unsigned ADDR_DEPTH   = (DEPTH > 1) ? $clog2(DEPTH) : 1
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
  T                    mem_q [DEPTH];
  logic [ADDR_DEPTH-1:0] rd_ptr_q, wr_ptr_q;
  logic [ADDR_DEPTH:0]   count_q;
  logic                  empty, push, pop;

  assign empty   = count_q == 0;
  assign ready_o = count_q != DEPTH;
  assign valid_o = !empty || (FALL_THROUGH && valid_i);
  assign data_o  = (FALL_THROUGH && empty) ? data_i : mem_q[rd_ptr_q];
  assign usage_o = count_q[ADDR_DEPTH-1:0];

  // A beat that falls through is never stored
  assign push = valid_i && ready_o && !(FALL_THROUGH && empty && ready_i);
  assign pop  = ready_i && !empty;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rd_ptr_q <= '0;
      wr_ptr_q <= '0;
      count_q  <= '0;
    end else if (flush_i) begin
      rd_ptr_q <= '0;
      wr_ptr_q <= '0;
      count_q  <= '0;
    end else begin
      if (push) begin
        mem_q[wr_ptr_q] <= data_i;
        wr_ptr_q        <= (wr_ptr_q == DEPTH - 1) ? '0 : wr_ptr_q + 1'b1;
      end
      if (pop) rd_ptr_q <= (rd_ptr_q == DEPTH - 1) ? '0 : rd_ptr_q + 1'b1;
      count_q <= count_q + push - pop;
    end
  end
endmodule
