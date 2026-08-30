// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_rgmii_tx_assertions
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Non-comprehensive assertions for an RGMII TX interface.
Enforces the inter-packet gap of 12 or more cycles and packet length of 64-1522
bytes as required by the RGMII spec.

The packet length requirement could be accomplished with a simple
$rose(phy_tx_ctl) |-> ##[64:1522] $fell(phy_tx_ctl) assertion,
but Verilator doesn't support those so I've just manually put in a counter
This counter should be stripped away during synthesis since it drives nothing
except the assertions.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
// Assertions only - no logic
ethernet_rgmii_tx_assertions u_ethernet_rgmii_tx_assertions (
    .phy_tx_clk  (),
    .phy_tx_ctl  (),
    .phy_reset_n ()
);

*/

module ethernet_rgmii_tx_assertions (
    input logic phy_tx_clk,
    input logic phy_tx_ctl,
    input logic phy_reset_n
);
    logic ctl_last;
    logic [11:0] cycle_counter;

    always_ff @ (posedge phy_tx_clk) begin
        if (!phy_reset_n)   ctl_last <= 0;
        else                ctl_last <= phy_tx_ctl;
    end

    always_ff @ (posedge phy_tx_clk) begin
        if (!phy_reset_n) begin
            cycle_counter <= 0;
        end else begin
            if (phy_tx_ctl == ctl_last) begin // no change this cycle
                cycle_counter <= (cycle_counter + (&cycle_counter ? 0 : 1)); // increment cycle counter (saturating at 4095)
            end else begin
                cycle_counter <= 1; // reset cycle counter on change, counting the first beat which was this rising edge
            end
        end
    end

    always @ (posedge phy_tx_clk) begin
        if (phy_tx_ctl != ctl_last) begin
            if (ctl_last) begin // we were transmitting, so cycle_counter reflects the packet length in bytes
                assert (cycle_counter >= 71 && cycle_counter <= 1530) else $error("RGMII TX packet length out of bounds: %0d bytes", cycle_counter);
                // minimum packet is 60 payload + 4 CRC + 7 byte preamble (sometimes the SFD is counted as part of the preamble, sometimes not, so we will just say 7 bytes of preamble)
                // maximum is 1518 payload + 4 CRC + 8 byte preamble (including the SFD)
                // in theory the preamble can be as long as you want want I've arbitrarily capped it at 1530 here
            end else begin // we were not transmitting, so cycle_counter reflects the inter-packet gap in bytes
                assert (cycle_counter >= 12) else $error("RGMII TX inter-packet gap too short: %0d bytes", cycle_counter);
                // Ethernet specification states that 12 bytes is the minimum inter-frame gap
            end
        end
    end
    // TODO add cover points for:
    // - cycle_counter terminating at 64
    // - cycle counter terminating at 1522
    // - inter-packet gap terminating at 12
    // - IPG growing counter saturating
endmodule
