// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: mem_to_ro_mem
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Takes in a mem_if_utils_pkg:: memory interface and forwards it to a downstream
memory interface, but blocks any write requests and responds to them
immediately with an error response. Negligible hardware is used.

A lot of input signals are ignored and outputs tied to constants, so expect to
see considerable constant propagation which may substantially optimise
neighbouring logic.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
mem_to_ro_mem u_mem_to_ro_mem (
    .clk_i,
    .rst_ni,
    .mem_req_i(),
    .mem_rsp_o(),
    .mem_req_o(),
    .mem_rsp_i()
);

*/

module mem_to_ro_mem #(
    parameter RESPONSE_TO_WRITE = 64'hBADD_BADD_BADD_BADD // what to put on rdata in response to a write transaction. Usually ignored but can be used to supply an error code to the host
) (
    input clk_i,
    input rst_ni,

    // incoming requests
    input  mem_if_utils_pkg::mem_req_t   mem_req_i,
    output mem_if_utils_pkg::mem_rsp_t   mem_rsp_o,

    // forwarded request, with writes blocked
    output mem_if_utils_pkg::mem_req_t   mem_req_o,
    input  mem_if_utils_pkg::mem_rsp_t   mem_rsp_i
);
    logic unused;
    assign unused = ^{mem_req_i.data,mem_req_i.be};

    assign mem_req_o.we   = 1'b0; // block all writes
    assign mem_req_o.data = '0;   // wdata is irrelevant for a read-only memory interface
    assign mem_req_o.be   = '0;   // wstrb is irrelevant for a read-only memory interface

    assign mem_req_o.addr = mem_req_i.addr;

    // For write requests, hide them from the downstream memory and respond immediately here
    assign mem_req_o.req = mem_req_i.we ? 1'b0 : mem_req_i.req;
    assign mem_rsp_o.gnt = mem_req_i.we ? 1'b1 : mem_rsp_i.gnt;

    // The response lags the grant by a cycle (https://github.com/pulp-platform/hwpe-doc/blob/master/protocols.rst#hwpe-mem)
    logic was_err;
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) was_err <= '0;
        else         was_err <= mem_req_i.req && mem_req_i.we; // make a note if we are responding to an error
    end

    assign mem_rsp_o.data = was_err ? RESPONSE_TO_WRITE : mem_rsp_i.data; // return the specified response for write requests, pass through data for read requests
    assign mem_rsp_o.err  = was_err ? 1'b1              : mem_rsp_i.err;  // indicate an error for write requests, pass through err for read requests
endmodule
