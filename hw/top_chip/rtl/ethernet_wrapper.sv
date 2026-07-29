// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module ethernet_wrapper (
  // AXI clocking and reset
  input logic clk_axi_i,        // AXI interface clock
  input logic rst_axi_ni,       // AXI reset, deassertion synchronous to clk_axi_i

  // Ethernet MAC clocking and reset
  input logic clk_125m_i,       // 125 MHz ethernet in-phase clock
  input logic clk_125m_quad_i,  // 125 MHz ethernet quadrature clock
  input logic clk_200m_i,       // 200 MHz IDELAYCTRL reference clock
  input logic rst_eth_ni,       // Ethernet MAC reset, deassertion synchronous to clk_125m_i

  // AXI device interface
  input  top_pkg::axi_dev_req_t  axi_req_i,
  output top_pkg::axi_dev_resp_t axi_resp_o,

  // Interrupt out
  output logic ethernet_irq_o,

  // RGMII signals to ethernet PHY
  input  logic       eth_rgmii_rx_clk_i,
  input  logic       eth_rgmii_rx_ctl_i,
  input  logic [3:0] eth_rgmii_rx_d_i,
  output logic       eth_rgmii_tx_clk_o,
  output logic       eth_rgmii_tx_en_o,
  output logic [3:0] eth_rgmii_tx_d_o,
  inout  logic       eth_rgmii_mdio_io,
  output logic       eth_rgmii_mdc_o
);
endmodule
