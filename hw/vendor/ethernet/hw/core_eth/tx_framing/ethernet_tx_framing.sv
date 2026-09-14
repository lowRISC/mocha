// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_tx_framing
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
TX framing control for Ethernet. Includes a write-only buffer for data to
to be transmitted, and an FSM for streaming that data out over an AXI Stream.

The FSM is triggered by a pulse on 'kick_tx_i' and runs to the length of
tx_config_i.packet_len.

Statuses:
While transmitting, the 'busy' signal will be asserted.
On the last cycle of transmission, 'done_pulse' will be high for one cycle.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

`include "prim_assert.sv"

/*
TX framing module
*/

module ethernet_tx_framing (
    input                               clk_i,
    input                               rst_ni,
    output ethernet_pkg::axis_t         tx_axis_o,           // AXI Stream output (data, valid, and last)
    input                               tx_axis_tready_i,    // backpressure from Ethernet MAC (legal for TX, not for RX)
    input  mem_if_utils_pkg::mem_req_t  data_buf_mem_req_i,  // memory interface requests from software
    output mem_if_utils_pkg::mem_rsp_t  data_buf_mem_rsp_o,  // memory interface response to software
    output ethernet_pkg::tx_status_t    tx_status_o,         // status signals
    input  ethernet_pkg::tx_config_t    tx_config_i,         // config signals
    input                               kick_tx_i            // PULSE to start a transaction. Must not arrive while tx_status_o.busy is high
);
    //////////////////
    // Declarations //
    //////////////////
    logic [ethernet_pkg::TX_DATA_BUF_ADDR_W-1:0] tx_buffer_addr,tx_buffer_addr_next; // address pointer for reading from the buffer
    logic tx_busy;

    ///////////////////////////////////////////////
    // Make the host memory interface write-only //
    ///////////////////////////////////////////////
    mem_if_utils_pkg::mem_req_t tx_buffer_wr_req;
    mem_if_utils_pkg::mem_rsp_t tx_buffer_wr_rsp;

    mem_to_wo_mem mem_filter_inst (
        .clk_i(clk_i),
        .rst_ni,
        .mem_req_i(data_buf_mem_req_i),
        .mem_rsp_o(data_buf_mem_rsp_o),
        .mem_req_o(tx_buffer_wr_req),
        .mem_rsp_i(tx_buffer_wr_rsp)
    );
    assign tx_buffer_wr_rsp.gnt = 1'b1; // grant all writes immediately
    // TODO block writes if a TX is in progress and the address hasn't been tx'd yet (but allow addresses that are already TX'd to allow efficient streaming of packets)
    // this would be very useful for preparing the next packet while the previous one is completing
    assign tx_buffer_wr_rsp.err = 1'b0; // TODO also detect writes our of bounds
    assign tx_buffer_wr_rsp.data = 64'hBADDF00DBADDF00D; // this data should never get used as this is a write-only memory

    /////////////////////////////////
    // Instantiate the data buffer //
    /////////////////////////////////
    // This instantiates a Xilinx Primitive Macro to generate RAM
    ram_downsizer_w64_r8 #( // TODO override memory size to be 1522 bytes instead of 2048
        .WR_ADDR_W  (ethernet_pkg::TX_DATA_BUF_ADDR_W-ethernet_pkg::TX_DATA_BUF_ADDR_LSBS) // subtract to convert from byte addresses to 64-bit word addresses
    ) tx_buffer (
        .clk_i,
        .rst_ni,
        // Writes from the host
        .wr_en_i    (tx_buffer_wr_req.req && tx_buffer_wr_req.we && &(tx_buffer_wr_req.be)),
        .wr_addr_i  (tx_buffer_wr_req.addr[ethernet_pkg::TX_DATA_BUF_ADDR_W-1:ethernet_pkg::TX_DATA_BUF_ADDR_LSBS]), // convert from byte address to word address
        .wr_data_i  (tx_buffer_wr_req.data),

        // Reads for the TX FSM
        .rd_en_i    (tx_busy | kick_tx_i), // keep reading data as long as we are busy transmitting, and on the first cycle
        .rd_addr_i  (tx_buffer_addr_next), // because of one cycle latency we pass in the NEXT address we will be transmitting
        .rd_data_o  (tx_axis_o.data)
    );

    //////////////////////
    // TX FSM and logic //
    //////////////////////
    assign tx_axis_o.user = '0; // user signal used to indicate errors, not used for TX for now
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            tx_busy <= 1'b0;
        end else begin
            if (kick_tx_i && !tx_busy) begin
                tx_busy <= 1'b1; // start transmitting when kicked
            end else if (tx_axis_o.valid && tx_axis_tready_i && tx_axis_o.last) begin
                tx_busy <= 1'b0; // stop transmitting after the last beat of the packet is accepted by the downstream
            end else begin
                tx_busy <= tx_busy; // hold value steady when no relevant event occurs
            end
        end
    end

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)    tx_buffer_addr <= '0;
        else            tx_buffer_addr <= tx_buffer_addr_next;
    end

    always_comb begin
        tx_buffer_addr_next = tx_buffer_addr; // default to hold value steady
        if (tx_axis_o.valid && tx_axis_tready_i) begin
            if (tx_axis_o.last) tx_buffer_addr_next = '0; // reset address pointer after the last beat of the packet is accepted by the downstream
            else                tx_buffer_addr_next = tx_buffer_addr + 1; // increment address pointer for the next beat
        end
    end
    assign tx_axis_o.last = tx_buffer_addr == tx_config_i.packet_len - 1; // assert last when the current beat is the last byte of the packet

    assign tx_axis_o.valid  = tx_busy;

    assign tx_status_o.busy = tx_busy;
    assign tx_status_o.done_pulse = tx_axis_o.valid && tx_axis_tready_i && tx_axis_o.last; // pulse when the last beat of the packet is accepted by the downstream

    ////////////////
    // Assertions //
    ////////////////
    // Assert the memory interface behaves correctly
    mem_if_assertions u_mem_if_assertions (
        .clk_i,
        .rst_ni,
        .mem_req_i(data_buf_mem_req_i),
        .mem_rsp_o(data_buf_mem_rsp_o)
    );

    // Assert other outputs are defined
    `ASSERT_KNOWN(TxAxisValidKnown_A,           tx_axis_o.valid);
    `ASSERT_KNOWN_IF(TxAxisDataKnown_A,         tx_axis_o.data, tx_axis_o.valid);
    `ASSERT_KNOWN_IF(TxAxisLastKnown_A,         tx_axis_o.last, tx_axis_o.valid);
    `ASSERT_KNOWN(TxStatusBusyKnown_A,          tx_status_o.busy);
    `ASSERT_KNOWN(TxStatusDonePulseKnown_A,     tx_status_o.done_pulse);

    // Assert this isn't used incorrectly
    `ASSERT(NoTxKickWhileBusy_A, ~(kick_tx_i && tx_status_o.busy)); // kick should not arrive while busy is high

    // Some behavioural assertions to check for integration mistakes or flag problematic behaviour
    `ASSERT_PULSE(TxKickIsPulse_A, kick_tx_i); // kick should be a pulse
    `ASSERT_PULSE(TxDoneIsPulse_A, tx_status_o.done_pulse); // done should be a pulse
    `ASSERT(TxMemIFGntGivenInstantly_A, data_buf_mem_req_i.req -> data_buf_mem_rsp_o.gnt); // the memory interface should grant immediately since there are no wait states

    // Assert the AXI Stream is standard compliant
    `ASSERT(TxAxisValidStaysUntilHandshake_A, tx_axis_o.valid && !tx_axis_tready_i |=> tx_axis_o.valid); // valid should stay high until the downstream is ready
    `ASSERT(TxAxisInvariantUntilHandshake_A,  tx_axis_o.valid && !tx_axis_tready_i |=> $stable(tx_axis_o.data) && $stable(tx_axis_o.last)); // data and last should stay the same until the downstream is ready

    // Assert behaviour under reset
    `ASSERT(TxAxisValidLowAtReset_A,   !rst_ni |-> !tx_axis_o.valid,             clk_i, 0);
    `ASSERT(TxBusyLowAtReset_A,        !rst_ni |-> !tx_status_o.busy,            clk_i, 0);
    `ASSERT(TxDoneLowAtReset_A,        !rst_ni |-> !tx_status_o.done_pulse,      clk_i, 0);
    //                                                                           ^ clk, ^ normally a reset to disable the assertion, but we want these to be true even under reset
endmodule
