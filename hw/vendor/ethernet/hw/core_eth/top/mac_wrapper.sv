// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: mac_wrapper
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Thin wrapper around rgmii_soc which creates an RGMII MAC
Exposes two AXI Streams:
    - TX: AXI Stream input to the MAC
    - RX: AXI Stream output from the MAC (no backpressure)
'tlast' should be taken as indicating the end of an Ethernet frame.
'tuser' should be interpreted as indicating an error in the frame.
The FCS will not be included in the AXI Stream, but the MAC will check it.

The module handles mapping signal names to the Alex Forencich RGMII MAC core

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

module mac_wrapper #(
    parameter TARGET = "XILINX"
) (
    // Clocks and resets
    input                                   clk_125M_i,     // main 125 MHz clock
    input                                   rst_ni,         // main active-low reset
    input                                   clk_125M_quad_i,// quadrature 125 MHz clock
    input                                   clk_200M_i,     // 200 MHz clock

    // Config/status
    output wire                             phy_reset_no,   // Active-low reset output to be routed to the PHY
    output ethernet_pkg::mac_status_t       mac_status_o,   // MAC Status struct
    input  ethernet_pkg::mac_config_t       mac_config_i,   // MAC Config struct

    // Ethernet: 1000BASE-T RGMII signals
    input  ethernet_pkg::eth_rgmii_rx_t     rgmii_rx_i,
    output ethernet_pkg::eth_rgmii_tx_t     rgmii_tx_o,

    // AXI Stream input for TX
    input  ethernet_pkg::axis_t             tx_axis_i,
    output logic                            tx_axis_tready_o,

    // AXI Stream output for RX (no backpressure)
    output ethernet_pkg::axis_t             rx_axis_o
);
    logic unused;
    assign unused = ^mac_config_i; // currently unused

    /////////////////////////
    // Instantiate the MAC //
    /////////////////////////
    rgmii_soc #(
        .TARGET(TARGET)
    ) rgmii_soc_inst (
        .rst_int        (~rst_ni                ), // rgmii_soc uses active HIGH reset (boy did I waste a lot of time discovering that)
        .clk_int        (clk_125M_i             ),
        .clk90_int      (clk_125M_quad_i        ),
        .clk_200_int    (clk_200M_i             ),

        .phy_rx_clk     (rgmii_rx_i.clk         ),
        .phy_rxd        (rgmii_rx_i.d           ),
        .phy_rx_ctl     (rgmii_rx_i.ctl         ),
        .phy_tx_clk     (rgmii_tx_o.clk         ),
        .phy_txd        (rgmii_tx_o.d           ),
        .phy_tx_ctl     (rgmii_tx_o.en          ),
        .phy_reset_n    (phy_reset_no           ),
        .mac_gmii_tx_en (mac_status_o.tx_busy   ),
        .tx_axis_tdata  (tx_axis_i.data         ),
        .tx_axis_tvalid (tx_axis_i.valid        ),
        .tx_axis_tlast  (tx_axis_i.last         ),
        .tx_axis_tready (tx_axis_tready_o       ),
        .tx_axis_tuser  (tx_axis_i.user         ), // Can be used to indicate an error in the frame
        .rx_axis_tdata  (rx_axis_o.data         ),
        .rx_axis_tvalid (rx_axis_o.valid        ),
        .rx_axis_tlast  (rx_axis_o.last         ),
        .rx_axis_tuser  (rx_axis_o.user         ) // Indicates a CRC error in the received frame
    );
endmodule
