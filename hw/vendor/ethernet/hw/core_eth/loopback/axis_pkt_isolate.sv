// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: axis_pkt_isolate
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Isolator for an AXI Stream with packets delimeted by tlast.

When isolate_i is asserted, the isolator will first complete any in-progress
packet, then zero the output stream and assert isolated_o.
Similarly, when isolate_i is deasserted, the isolator will wait until any in-
progress packet is complete before allowing data to flow through and deasserting
isolated_o.
Therefore isolated_o is generally equal to isolated_i, but may lag changes
by an arbitrary amount of time to allow packets to complete.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

module axis_pkt_isolate (
    input  logic  clk_i,
    input  logic  rst_ni,
    input  ethernet_pkg::axis_t axis_i,
    output ethernet_pkg::axis_t axis_o,
    input  logic  isolate_i,
    output logic  isolated_o
);
    // Track if we are mid-packet to avoid cutting off a packet or un-isolating mid-packet
    logic packet_in_progress;
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) packet_in_progress <= 1'b0;
        else begin
            if (axis_i.valid) begin
                packet_in_progress <= !axis_i.last;
            end
        end
    end
    // packet_in_progress being asserted means some data has been captured for this packet
    // i.e. it will not be asserted DURING the first beat but will rise once the first beat is captured
    // it will fall just after the last beat is captured as indicated by tlast
    // note that it will fall even if valid is asserted on the following cycle, so for back-to-back packets we will still see packet_in_progress go low for one cycle
    // this makes sense: the packet is not considered to be "in progress" until we have captured some data for it
    // this one cycle of low is important because it allows us to switch isolation state between packets

    // Track the isolation state. We only change the state when we are not mid-packet.
    logic isolated_q;
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) isolated_q <= 1'b1; // default to isolated on reset, just in case
        else if (!packet_in_progress) isolated_q <= isolate_i;
    end
    assign isolated_o = packet_in_progress ? isolated_q : isolate_i;
    // If no packet in progress, passthrough isolate_i to isolated_o. If a packet is in progress, we need to retain our previous isolation state until the packet is complete.
    // Be careful if you are messing with this logic!
    // There is some subtle timing here e.g. on the first beat of a new packet

    // Implement the isolation logic
    assign axis_o = isolated_o ? '0 : axis_i;
endmodule
