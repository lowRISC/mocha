// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: axis_pkt_mux
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Multiplexor for two AXI Stream (AXIS) streams with packets delimeted by tlast.

This is not entirely trivial because we have to prevent "packet splices"
i.e. if the select lines toggles in the middle of a packet on one stream, we
should never see:
    - a partial packet on the output stream
    - a packet on the output stream that mixes data from the both input streams

To avoid this, we have an 'isolator' on each input stream. This has an
isolate_i input and an isolated_o output. When isolate_i is asserted, the
isolator will complete any existing packets before asserting isolated_o.
Similarly when it is deasserted, the isolator will wait until any already-
ongoing packets are complete before allowing data to flow through.

To ensure splicing is impossible, the isolated_o signals from both isolators
are fed back into one another's isolate_i inputs. This is not unlike a NAND
latch but with delays on the feedback paths.

Does not:
    - Support backpressure TODO
    - Do anything fancy with IDs
    - Pay any special attention to any AXIS signals except tvalid and tlast

Note: this module has potential to be refactored for reusability given AXIS is
a standard interface. For now it is only used in Ethernet so that's not a
priority.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

`include "prim_assert.sv"

module axis_pkt_mux (
    input  clk_i,
    input  rst_ni,
    input  logic sel_i,                     // Select signal for one of the two input streams
    output logic passthrough_o,             // when asserted, the output stream is passing through the selected input stream. Should be normally high but may be briefly deasserted when sel_i changes to allow the isolators to complete any in-progress packets
    input  ethernet_pkg::axis_t axis_i [2], // Input streams to be MUXed
    output ethernet_pkg::axis_t axis_o      // Multiplexed output stream
);
    ethernet_pkg::axis_t axis_isolated [2];

    // Flop the output stream
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)    axis_o <= '0;
        else            axis_o <= axis_isolated[0] | axis_isolated[1]; // The isolation logic zeros any isolated stream, so we can just OR them together
    end

    // This is really cool!
    // It behaves similarly to an NAND latch with the symmetrical feedback paths
    // When loopback_en_i switches state, it will FIRST isolate the currently selected path,
    // then once the isolated_o signal for that path is asserted, that will allow the other path to be un-isolated
    logic isolated   [2];
    logic isolated_q [2];
    // registered version of isolated to avoid combinational loops. Shouldn't be necessary really but some EDA tools will probably be upset by it.
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            isolated_q[0] <= 1'b1;
            isolated_q[1] <= 1'b1;
        end else begin
            isolated_q[0] <= isolated[0];
            isolated_q[1] <= isolated[1];
        end
    end

    axis_pkt_isolate isolate0 (
        .clk_i,
        .rst_ni,
        .axis_i(axis_i[0]),
        .axis_o(axis_isolated[0]),
        .isolate_i(sel_i | !isolated_q[1]),
        .isolated_o(isolated[0])
    );

    axis_pkt_isolate isolate1 (
        .clk_i,
        .rst_ni,
        .axis_i(axis_i[1]),
        .axis_o(axis_isolated[1]),
        .isolate_i(!sel_i | !isolated_q[0]),
        .isolated_o(isolated[1])
    );

    assign passthrough_o = !isolated[0] || !isolated[1]; // when either path is un-isolated, we are passing through the selected input stream

    `ASSERT(NeverMixPaths_A, isolated[0] || isolated[1]) // we should NEVER have both paths un-isolated at the same time, otherwise we could see a packet splice
endmodule
