// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: axis_pkt_ring_buffer_wr_ptr_logic
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Simple write pointer logic with signals 'valid', 'commit', 'abandon'. Tracks a
write pointer and a head pointer (which points to the start of the current
packet being captured).

* When 'valid' is asserted alone, the write pointer is incremented.
* When 'valid' and 'abandon' are asserted, the write pointer moves back to the head pointer
* When 'valid' and 'commit' are asserted, the head pointer update to the current value of the write pointer, then the write pointer increments.

'valid', 'abandon', and 'commit' should never be asserted all together.

Write pointer will simply wrap when it saturates.

DOES NOT:
    - Does not actually handle any data - this is purely for write pointer logic, the memory and associated datapath should be elsewhere
    - Does not detect buffer overflows - you are responsible for comparing wr_ptr_o with a 'free pointer' or similar to detect overflows

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
axis_pkt_ring_buffer testbench.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
// This simple module will advance the write pointer whenever valid_i is asserted
// and also track the head of the current packet. If 'abandon' is asserted, the write
// pointer moves back to the head of the packet. If 'commit' is asserted, the head
// of the current packet is updated to where the write pointer is. See inside
// for more details.
axis_pkt_ring_buffer_wr_ptr_logic #(
    .PTR_W()
) buf_wr_ptr_logic (
    .clk_i,
    .rst_ni,
    .valid_i        (), // increments write pointer
    .commit_i       (), // valid with valid_i, causes head pointer to be updated to write pointer
    .abandon_i      (), // valid with valid_i, causes the write pointer to revert to the head pointer
    .wr_ptr_o       (), // next location to write to
    .head_ptr_o     () // head of current packet
);
*/

`include "prim_assert.sv" // for ASSERT and ASSERT_KNOWN macros

module axis_pkt_ring_buffer_wr_ptr_logic #(
    parameter  PTR_W        = 17,                   // pointer width
    localparam type ptr_t   = logic [PTR_W-1:0]     // pointer type
) (
    input       clk_i,  // clock
    input       rst_ni, // active-low asynchronous reset

    // A packet is ended by 'valid' being asserted with either 'abandon' or 'commit'
    input       valid_i,    // indicates data was written this cycle, so the write pointer should advance
    input       commit_i,   // indicates data was written this cycle and was the last piece of data in this packet (write pointer will advanced, and head pointer will be updated)
    input       abandon_i,  // valid when valid_i is asserted. Indicates this packet should be abandoned. wr_ptr_o will revert to the value of head_ptr_o

    output ptr_t wr_ptr_o,  // write pointer, points to the next location to write to
    output ptr_t head_ptr_o // head pointer, points to the start of the current packet (updated by commit_i && valid_i)
);
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            wr_ptr_o  <= '0;
        end else if (valid_i) begin
            if (abandon_i)  wr_ptr_o <= head_ptr_o;
            else            wr_ptr_o <= wr_ptr_o + 1;
        end
    end

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            head_ptr_o <= '0;
        end else begin
            if (commit_i && valid_i) head_ptr_o <= wr_ptr_o + 1; // at the start of a new packet, update the head pointer to the current write pointer (which points to the next location to write to, so effectively the end of the previous packet)
        end
    end

    ////////////////
    // Assertions //
    ////////////////
    `ASSERT_KNOWN(WrPtrO_A,     wr_ptr_o);
    `ASSERT_KNOWN(HeadPtrO_A,   head_ptr_o);

    `ASSERT(WrPtrLogicInputsGood_A, ~(valid_i && commit_i && abandon_i), "valid, commit, and abandon should never be asserted all together");
endmodule
