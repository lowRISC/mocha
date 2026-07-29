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
  output logic       eth_rgmii_mdc_o,

  // PHY reset
  output logic       eth_phy_reset_no
);
  // AXI signals from CDC FIFO to axi_to_mem, synchronous to clk_125m
  top_pkg::axi_dev_req_t  axi_125m_req;
  top_pkg::axi_dev_resp_t axi_125m_rsp;

  ///////////////////////////////
  // CDC to the Ethernet clock //
  ///////////////////////////////

  // Synchronise AXI bus from clk_axi_i to clk_125m_i
  axi_cdc #(
    .aw_chan_t  ( top_pkg::axi_dev_aw_chan_t ),
    .w_chan_t   ( top_pkg::axi_w_chan_t      ),
    .b_chan_t   ( top_pkg::axi_dev_b_chan_t  ),
    .ar_chan_t  ( top_pkg::axi_dev_ar_chan_t ),
    .r_chan_t   ( top_pkg::axi_dev_r_chan_t  ),
    .axi_req_t  ( top_pkg::axi_dev_req_t     ),
    .axi_resp_t ( top_pkg::axi_dev_resp_t    ),
    .LogDepth   ( 3                          ),
    .SyncStages ( 2                          )  // Needs to be 2 for prim_flop_2sync
  ) u_eth_async_axi_fifo (
    .src_clk_i  (clk_axi_i),
    .src_rst_ni (rst_axi_ni),
    .src_req_i  (axi_req_i),
    .src_resp_o (axi_resp_o),
    .dst_clk_i  (clk_125m_i),
    .dst_rst_ni (rst_eth_ni),
    .dst_req_o  (axi_125m_req),
    .dst_resp_i (axi_125m_rsp)
  );

  // The interrupt line needs to be synchronised back to the main clock domain
  logic ethernet_irq_125m_q; // First flop the IRQ on source domain to deglitch
  prim_flop u_eth_irq_flop (
    .clk_i  (clk_125m_i),
    .rst_ni (rst_eth_ni),
    .d_i    (ethernet_irq_125m),
    .q_o    (ethernet_irq_125m_q)
  );
  prim_flop_2sync #(
    .Width      (1),
    .ResetValue (1'b0)
  ) u_eth_irq_sync (
    .clk_i  (clk_axi_i),
    .rst_ni (rst_axi_ni),
    .d_i    (ethernet_irq_125m_q),
    .q_o    (ethernet_irq_o)
  );

  //////////////////////////////
  // Instantiate ethernet_top //
  ///////////////////////////////

  ethernet_pkg::eth_rgmii_rx_t        eth_rgmii_rx;
  ethernet_pkg::eth_rgmii_tx_t        eth_rgmii_tx;
  ethernet_pkg::eth_rgmii_mdio_in_t   eth_mdio_in; // actually just an alias for logic but I like the consistent naming convention
  ethernet_pkg::eth_rgmii_mdio_out_t  eth_mdio_out;

  ethernet_top_axi #(
    .TARGET     ( "XILINX" ),
    .axi_req_t  ( top_pkg::axi_dev_req_t     ),
    .axi_rsp_t  ( top_pkg::axi_dev_resp_t    )
  ) ethernet_inst (
    // Clocking and reset
    .clk_125M_i        (clk_125m_i),        // Main clock - used by memory interface and as 125 MHz ethernet in-phase clock
    .rst_ni            (rst_eth_ni),        // Main reset, deassertion synchronous to clk_125m_i
    .clk_125M_quad_i   (clk_125m_quad_i),   // 125 MHz ethernet quadrature clock (used by MAC)
    .clk_200M_i        (clk_200m_i),        // 200 MHz IDELAYCTRL reference clock
    .axi_req_i         (axi_125m_req),      // Synchronous to clk_125M_i
    .axi_rsp_o         (axi_125m_rsp),      // Synchronous to clk_125M_i
    .eth_rgmii_rx_i    (eth_rgmii_rx),
    .eth_rgmii_tx_o    (eth_rgmii_tx),
    .eth_rgmii_mdio_i  (eth_mdio_in),
    .eth_rgmii_mdio_o  (eth_mdio_out),
    .ethernet_irq_o    (ethernet_irq_125m),
    .phy_reset_no      (eth_phy_reset_no)
  );

  //////////////////////////
  // RGMII signal mapping //
  //////////////////////////
  assign eth_rgmii_rx.clk   = eth_rgmii_rx_clk_i;
  assign eth_rgmii_rx.ctl   = eth_rgmii_rx_ctl_i;
  assign eth_rgmii_rx.d     = eth_rgmii_rx_d_i;
  assign eth_rgmii_tx_clk_o = eth_rgmii_tx.clk;
  assign eth_rgmii_tx_en_o  = eth_rgmii_tx.en;
  assign eth_rgmii_tx_d_o   = eth_rgmii_tx.d;

  //////////////////////////////////
  // MDIO bidirectional IO buffer //
  //////////////////////////////////
  IOBUF u_mdio_iobuf (
    .O  (eth_mdio_in),       // Buffer output
    .IO (eth_rgmii_mdio_io), // Buffer inout port (connect directly to top-level port)
    .I  (eth_mdio_out.o),    // Buffer input
    .T  (~eth_mdio_out.oen)  // 3-state enable input, high=input, low=output
  );
  assign eth_rgmii_mdc_o = eth_mdio_out.c;

endmodule
