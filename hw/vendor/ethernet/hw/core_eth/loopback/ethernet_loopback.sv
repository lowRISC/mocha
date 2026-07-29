// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_loopback
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Thin wrapper around axis_pkt_mux
Multiplexes the RX path between the actual RX (from the MAC) and the TX (for
loopback).

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

module ethernet_loopback (
    input  clk_i,
    input  rst_ni,
    input  loopback_en,
    input  axis_tx_ready_i,
    input  ethernet_pkg::axis_t axis_rx_real_i,
    input  ethernet_pkg::axis_t axis_tx_i,
    output ethernet_pkg::axis_t axis_o        // Multiplexed output stream
);
    ethernet_pkg::axis_t tx_axis_modified;
    // The axis_pkt_mux does not support backpressure generally
    // but in the Ethernet case we know the only backpressure is on the TX path,
    // so we can just gate tvalid with tready on the TX path for this
    // This is completely fine for Ethernet but is not generally true for AXIS, so we don't want to change the axis_pkt_mux module itself
    assign tx_axis_modified.valid = axis_tx_i.valid & axis_tx_ready_i;
    assign tx_axis_modified.data  = axis_tx_i.data;
    assign tx_axis_modified.last  = axis_tx_i.last;
    assign tx_axis_modified.user  = axis_tx_i.user;

    axis_pkt_mux loopback_mux (
        .clk_i,
        .rst_ni,
        .sel_i          (loopback_en), // select between TX and RX for loopback
        .passthrough_o  (), // deasserts briefly when mid-switch. Not used here
        .axis_i         ({axis_rx_real_i,tx_axis_modified}), // RX path is input 0, TX path is input 1
        .axis_o         (axis_o)
    );

endmodule
