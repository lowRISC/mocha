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
  input  top_pkg::axi_req_t  axi_req_i,
  output top_pkg::axi_resp_t axi_resp_o,

  // Interrupt out
  output logic ethernet_irq_o,

  // RGMII signals to ethernet PHY
  input  logic       eth_rgmii_rxck_i,
  input  logic       eth_rgmii_rxctl_i,
  input  logic [3:0] eth_rgmii_rxd_i,
  output logic       eth_rgmii_txck_o,
  output logic       eth_rgmii_txctl_o,
  output logic [3:0] eth_rgmii_txd_o,
  inout  logic       eth_rgmii_mdio_io,
  output logic       eth_rgmii_mdc_o
);
  // AXI signals from CDC FIFO to axi_to_mem, synchronous to clk_125m
  top_pkg::axi_req_t  eth_125m_req;
  top_pkg::axi_resp_t eth_125m_resp;

  // Framing top 64-bit memory format signals
  logic                               eth_en;
  logic [  top_pkg::AxiAddrWidth-1:0] eth_addr;
  logic [  top_pkg::AxiDataWidth-1:0] eth_wrdata;
  logic [top_pkg::AxiDataWidth/8-1:0] eth_be;
  logic                               eth_we;
  logic                               eth_rvalid;
  logic [  top_pkg::AxiDataWidth-1:0] eth_rdata;

  // MDIO buffer control signals
  logic eth_mdio_i;
  logic eth_mdio_o;
  logic eth_mdio_oe;

  // Async AXI FIFO from clk_axi_i to clk_125m_i
  axi_cdc #(
    .aw_chan_t  ( top_pkg::axi_aw_chan_t ),
    .w_chan_t   ( top_pkg::axi_w_chan_t  ),
    .b_chan_t   ( top_pkg::axi_b_chan_t  ),
    .ar_chan_t  ( top_pkg::axi_ar_chan_t ),
    .r_chan_t   ( top_pkg::axi_r_chan_t  ),
    .axi_req_t  ( top_pkg::axi_req_t     ),
    .axi_resp_t ( top_pkg::axi_resp_t    ),
    .LogDepth   ( 3                      ),
    .SyncStages ( 2                      )  // Needs to be 2 for prim_flop_2sync
  ) u_eth_async_axi_fifo (
    .src_clk_i  (clk_axi_i),
    .src_rst_ni (rst_axi_ni),
    .src_req_i  (axi_req_i),
    .src_resp_o (axi_resp_o),
    .dst_clk_i  (clk_125m_i),
    .dst_rst_ni (rst_eth_ni),
    .dst_req_o  (eth_125m_req),
    .dst_resp_i (eth_125m_resp)
  );

  // AXI to mem for framing top
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_eth_axi_to_mem (
    .clk_i  (clk_125m_i),
    .rst_ni (rst_eth_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (eth_125m_req),
    .axi_resp_o (eth_125m_resp),

    // Memory interface.
    .mem_req_o    (eth_en),
    .mem_gnt_i    (1'b1),
    .mem_addr_o   (eth_addr),
    .mem_wdata_o  (eth_wrdata),
    .mem_strb_o   (eth_be),
    .mem_atop_o   ( ),
    .mem_we_o     (eth_we),
    .mem_rvalid_i (eth_rvalid),
    .mem_rdata_i  (eth_rdata)
  );

  // Single-cycle read response.
  always_ff @(posedge clk_125m_i or negedge rst_eth_ni) begin
    if (!rst_eth_ni) begin
      eth_rvalid <= '0;
    end else begin
      eth_rvalid <= eth_en; // Generate rvalid strobes even for writes
    end
  end

  // Packet framing top
  framing_top u_framing_top (
    // Memory interface.
    .msoc_clk       (clk_125m_i), // Some internal logic assumes msoc_clk == clk_int
    .core_lsu_addr  (eth_addr[14:0]),
    .core_lsu_wdata (eth_wrdata),
    .core_lsu_be    (eth_be),
    .ce_d           (eth_en),
    .we_d           (eth_en & eth_we),
    .framing_sel    (eth_en),
    .framing_rdata  (eth_rdata),
    .rst_int        (!rst_eth_ni),

    // Clocks.
    .clk_int     (clk_125m_i),      // 125 MHz in-phase
    .clk90_int   (clk_125m_quad_i), // 125 MHz quadrature
    .clk_200_int (clk_200m_i),

    // 1000BASE-T RGMII PHY interface.
    .phy_rx_clk  (eth_rgmii_rxck_i),
    .phy_rxd     (eth_rgmii_rxd_i),
    .phy_rx_ctl  (eth_rgmii_rxctl_i),
    .phy_tx_clk  (eth_rgmii_txck_o),
    .phy_txd     (eth_rgmii_txd_o),
    .phy_tx_ctl  (eth_rgmii_txctl_o),
    .phy_reset_n ( ), // Do not use rst_int for PHY reset
    .phy_int_n   ( ),
    .phy_pme_n   ( ),
    .phy_mdc     (eth_rgmii_mdc_o),
    .phy_mdio_i  (eth_mdio_i),
    .phy_mdio_o  (eth_mdio_o),
    .phy_mdio_oe (eth_mdio_oe),

    // Interrupt out.
    .eth_irq (ethernet_irq)
  );

  // MDIO bidirectional IO buffer
  IOBUF u_mdio_iobuf (
    .O  (eth_mdio_i),        // Buffer output
    .IO (eth_rgmii_mdio_io), // Buffer inout port (connect directly to top-level port)
    .I  (eth_mdio_o),        // Buffer input
    .T  (~eth_mdio_oe)       // 3-state enable input, high=input, low=output
  );

endmodule
