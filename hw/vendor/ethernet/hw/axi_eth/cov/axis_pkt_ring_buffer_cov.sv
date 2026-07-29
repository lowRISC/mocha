// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: axis_pkt_ring_buffer_cov
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Coverage collection for the axis_pkt_ring_buffer

NOTE: This module is experimental and not yet fully implemented.

*/

module axis_pkt_ring_buffer_cov;
`ifdef COVERAGE
    covergroup axis_pkt_ring_buffer_cg @(posedge axis_pkt_ring_buffer.clk_i);
        // AXI Stream
        cp_pkt_tvalid           : coverpoint axis_pkt_ring_buffer.pkt_tvalid_i;
        cp_pkt_tlast            : coverpoint axis_pkt_ring_buffer.pkt_tlast_i;
        cp_pkt_abandon          : coverpoint axis_pkt_ring_buffer.pkt_abandon_i;

        // Packet handling
        cp_commit_pkt           : coverpoint axis_pkt_ring_buffer.commit_pkt;
        cp_abandon_pkt          : coverpoint axis_pkt_ring_buffer.abandon_pkt;
        cp_buf_write            : coverpoint axis_pkt_ring_buffer.buf_write;
        cp_buf_almost_full      : coverpoint axis_pkt_ring_buffer.buf_almost_full_o;
        cp_buf_full             : coverpoint axis_pkt_ring_buffer.buf_full;
        cp_table_full           : coverpoint axis_pkt_ring_buffer.table_full_o;
        cp_table_almost_full    : coverpoint axis_pkt_ring_buffer.table_almost_full_o;

        // Crosses
        cp_pkt_tlastXcp_buf_full    : cross cp_pkt_tlast, cp_buf_full;     // cover last during full buffer, or full buffer without last
        cp_pkt_tlastXcp_table_full  : cross cp_pkt_tlast, cp_table_full; // cover last during full table, or full table without last
    endgroup
    axis_pkt_ring_buffer_cg axis_pkt_ring_buffer_cg_inst;
    initial axis_pkt_ring_buffer_cg_inst = new();

    property full_table_pop_during_packet;
        @(posedge axis_pkt_ring_buffer.clk_i) disable iff (!axis_pkt_ring_buffer.rst_ni)
        1
        // TODO express this property
        // - the table was full when a packet began
        // - a pop occured while the packet was being received
        // - the packet was committed (not abandoned)
    endproperty cover property(full_table_pop_during_packet);

`endif
endmodule
