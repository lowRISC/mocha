// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Primitive wrappers for Pulp register header
// __q: Q output of FF
// __d: D input of FF
// __load: load d value into FF
// __reset_value: value assigned upon reset
// __clk: clock input
// __arst_n: asynchronous reset, active-low
// __arst: asynchronous reset, active-high

`ifndef LOWRISC_COMMON_CELLS_REGISTERS_SVH_
`define LOWRISC_COMMON_CELLS_REGISTERS_SVH_

// Flip-Flop with asynchronous active-low reset
`define FF(__q, __d, __reset_value, __clk = clk_i, __arst_n = rst_ni) \
  `PRIM_FLOP_A(__d, __q, __reset_value, __clk, __arst_n)

// Flip-Flop with no reset,
// if (1) begin..end is needed so that FFNR can be used more than once in
// the same module.
`define FFNR(__q, __d, __clk = clk_i) \
  if (1) begin \
    prim_flop_no_rst #(.Width($bits(__q))) u_flop_no_rst ( \
      .clk_i(__clk), \
      .d_i(__d), \
      .q_o(__q) \
    ); \
  end

// Flip-Flop with asynchronous active-high reset
`define FFAR(__q, __d, __reset_value, __clk, __arst) \
  `FF(__q, __d, __reset_value, __clk, ~__arst)

// Flip-Flop with asynchronous active-low reset
`define FFARN(__q, __d, __reset_value, __clk, __arst_n) \
  `FF(__q, __d, __reset_value, __clk, __arst_n)

// Flip-Flop with load-enable and asynchronous active-low reset
`define FFL(__q, __d, __load, __reset_value, __clk = clk_i, __arst_n = rst_ni) \
  `FF(__q, __load ? __d : __q, __reset_value, __clk, __arst_n)

// Flip-Flop with load-enable and no reset
`define FFLNR(__q, __d, __load, __clk = clk_i) \
  `FFNR(__q, __load ? __d : __q, __clk)

// Flip-Flop with load-enable and asynchronous active-high reset
`define FFLAR(__q, __d, __load, __reset_value, __clk, __arst) \
  `FFL(__q, __d, __load, __reset_value, __clk, ~__arst)

// Flip-Flop with load-enable and asynchronous active-low reset
`define FFLARN(__q, __d, __load, __reset_value, __clk, __arst_n) \
  `FFL(__q, __d, __load, __reset_value, __clk, __arst_n)

// Flip-Flop with load-enable and asynchronous active-low reset and synchronous clear
`define FFLARNC(__q, __d, __load, __clear, __reset_value, __clk, __arst_n) \
  `FFL(__q, __clear ? __reset_value : __d, __load | __clear, __reset_value, __clk, __arst_n)

`endif
