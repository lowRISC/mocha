// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Formal verification testbench for riscv_debug_module.

module riscv_debug_module_tb (
  input  logic clk_i,
  input  logic rst_ni,
  input  logic debug_en_i,
  output logic debug_en_o,

  input  logic tms_i,
  input  logic td_i,
  output logic td_o,
  output logic td_en_o,
  input  logic trst_ni,

  output top_pkg::axi_req_t      axi_host_req_o,
  input  top_pkg::axi_resp_t     axi_host_resp_i,
  input  top_pkg::axi_dev_req_t  axi_device_req_i,
  output top_pkg::axi_dev_resp_t axi_device_resp_o,

  output logic ndmreset_req_o,
  input  logic ndmreset_ack_i,

  output logic debug_req_o
);

  localparam config_pkg::cva6_cfg_t CVA6Cfg =
      build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

  riscv_debug_module #(
    .CVA6Cfg ( CVA6Cfg      ),
    .XLen    ( CVA6Cfg.XLEN )
  ) dut (
    .clk_i,
    .rst_ni,
    .debug_en_i,
    .debug_en_o,
    // Clocking the JTAG side from clk_i avoids needing a second clock in the
    // generic FPV setup.
    .tck_i (clk_i),
    .tms_i,
    .td_i,
    .td_o,
    .td_en_o,
    // Anding with the existing rst_ni avoids needing a second reset in the
    // FPV setup.
    .trst_ni (trst_ni & rst_ni),
    .axi_host_req_o,
    .axi_host_resp_i,
    .axi_device_req_i,
    .axi_device_resp_o,
    .ndmreset_req_o,
    .ndmreset_ack_i,
    .debug_req_o
  );

endmodule : riscv_debug_module_tb
