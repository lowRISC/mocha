// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package clkmgr_pkg;

  typedef enum int {
    HintMainHint = 0
  } hint_names_e;

  // clocks generated and broadcast
  typedef struct packed {
    logic clk_main_powerup;
    logic clk_io_powerup;
    logic clk_aon_powerup;
    logic clk_main_hint;
    logic clk_main_infra;
    logic clk_io_infra;
    logic clk_io_peri;
  } clkmgr_out_t;

  // clock gating indication for alert handler
  typedef struct packed {
    prim_mubi_pkg::mubi4_t main_powerup;
    prim_mubi_pkg::mubi4_t io_powerup;
    prim_mubi_pkg::mubi4_t aon_powerup;
    prim_mubi_pkg::mubi4_t main_hint;
    prim_mubi_pkg::mubi4_t main_infra;
    prim_mubi_pkg::mubi4_t io_infra;
    prim_mubi_pkg::mubi4_t io_peri;
  } clkmgr_cg_en_t;

  parameter int NumOutputClk = 7;


  typedef struct packed {
    logic [1-1:0] idle;
  } clk_hint_status_t;

  parameter clk_hint_status_t CLK_HINT_STATUS_DEFAULT = '{
    idle: {1{1'b1}}
  };

endpackage // clkmgr_pkg
