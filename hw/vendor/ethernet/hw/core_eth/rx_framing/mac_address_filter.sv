// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: mac_address_filter
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Monitors Ethernet packets of AXI Stream (packets delimited using TLAST)

When a new packet starts, capture_reason will be invalid for the first 6 bytes
while it reads in the destination MAC address. Then it will give one of:
    MAC_MATCHES
    MAC_MULTICAST
    MAC_BROADCAST
    NON_MAC_MATCH
indicating the type of MAC address seen.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
mac_address_filter mac_address_filter_inst (
    .clk_i              (), // clock
    .rst_ni             (), // reset, active low
    .rx_axis_i          (), // AXI Stream input (data, valid, and last)
    .mac_addr_i         (), // should be reasonably static, configuration signal
    .capture_reason_o   () // valid after the first 6 bytes of a packet have been received
);

*/

module mac_address_filter (
    input       clk_i,
    input       rst_ni,

    input logic [47:0] mac_addr_i, // MAC address to filter for
    input ethernet_pkg::axis_t rx_axis_i,
    output ethernet_pkg::capture_reason_e capture_reason_o
);
    localparam logic [47:24] multicast_address = 24'h01005E; // multicast addresses begin like this

    logic [2:0] n_mac_bytes_checked; // count of how many bytes of the MAC address have been checked

    logic could_be_broadcast_next, could_be_broadcast_q;
    logic could_be_mac_match_next, could_be_mac_match_q;
    logic could_be_multicast_next, could_be_multicast_q;

    assign could_be_broadcast_next = could_be_broadcast_q && (rx_axis_i.data == 8'hFF);
    assign could_be_mac_match_next = could_be_mac_match_q && (rx_axis_i.data == mac_addr_i[47 - n_mac_bytes_checked*8 -: 8]);
    assign could_be_multicast_next = could_be_multicast_q && (rx_axis_i.data == multicast_address[47 - n_mac_bytes_checked*8 -: 8]);

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            n_mac_bytes_checked  <= 3'b0;
        end else if (rx_axis_i.valid && rx_axis_i.last) begin
            n_mac_bytes_checked <= 3'b0; // reset the count at the start of a new packet
        end else if (rx_axis_i.valid && n_mac_bytes_checked < 6) begin
            n_mac_bytes_checked <= n_mac_bytes_checked + 1; // increment the count while we are receiving the first 6 bytes
        end
    end

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) could_be_broadcast_q <= 1'b1;
        else if (rx_axis_i.valid && rx_axis_i.last) begin
            could_be_broadcast_q <= 1'b1; // reset for a new packet
        end else if (rx_axis_i.valid && n_mac_bytes_checked < 6) begin
            could_be_broadcast_q <= could_be_broadcast_next;
        end
    end

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) could_be_mac_match_q <= 1'b1;
        else if (rx_axis_i.valid && rx_axis_i.last) begin
            could_be_mac_match_q <= 1'b1; // reset for a new packet
        end else if (rx_axis_i.valid && n_mac_bytes_checked < 6) begin
            could_be_mac_match_q <= could_be_mac_match_next;
        end
    end

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) could_be_multicast_q <= 1'b1;
        else if (rx_axis_i.valid && rx_axis_i.last) begin
            could_be_multicast_q <= 1'b1; // reset for a new packet
        end else if (rx_axis_i.valid && n_mac_bytes_checked < 3) begin
            could_be_multicast_q <= could_be_multicast_next;
        end
    end

    assign capture_reason_o = could_be_mac_match_q ? ethernet_pkg::MAC_MATCHES :
                              could_be_multicast_q ? ethernet_pkg::MAC_MULTICAST :
                              could_be_broadcast_q ? ethernet_pkg::MAC_BROADCAST :
                              ethernet_pkg::NON_MAC_MATCH;

    logic unused;
    assign unused = rx_axis_i.user; // suppress unused signal warning
endmodule
