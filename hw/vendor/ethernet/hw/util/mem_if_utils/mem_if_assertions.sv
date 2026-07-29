// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: mem_if_assertions
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Assertions governing the behaviour of the memory interface defined in
mem_if_utils_pkg. Uses lowRISC prim_assert.sv for assertion macros.

This module only contains assertions - it has not functional behaviour and
will not affect synthesis.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
N/A

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
// This module is assertion only, no logic
mem_if_assertions u_mem_if_assertions (
    .clk_i,
    .rst_ni,
    .mem_req_i(),
    .mem_rsp_o()
);

*/

`include "prim_assert.sv"

module mem_if_assertions (
    input                               clk_i,  // This signal may look unused, but the `ASSERT macro has clk_i and rst_ni as defaults hardcoded
    input                               rst_ni, // This signal may look unused, but the `ASSERT macro has clk_i and rst_ni as defaults hardcoded
    input  mem_if_utils_pkg::mem_req_t  mem_req_i,
    input  mem_if_utils_pkg::mem_rsp_t  mem_rsp_o
);
    logic unused;
    assign unused = ^{clk_i,rst_ni,mem_req_i,mem_rsp_o}; // if `ASSERT is not used, these signals go nowhere after pre-processing, so we need to mark them as unused to avoid lint warnings

    // Once asserted, req should stay asserted until the handshake is complete
    `ASSERT(MemIfReqValidStaysUntilRsp_A,       mem_req_i.req && !mem_rsp_o.gnt |=> mem_req_i.req);

    // Once asserted, the request signals should stay stable until the handshake is complete
    `ASSERT(MemIfReqInvariantUntilRsp_A,        mem_req_i.req && !mem_rsp_o.gnt |=> $stable({mem_req_i.addr,mem_req_i.data,mem_req_i.we,mem_req_i.be}));

    // Assert that all signals are known when the protocol requires it
    `ASSERT_KNOWN(MemIfReqKnown_A,              mem_req_i.req) // req always known
    `ASSERT_KNOWN(MemIfGntKnown_A,              mem_rsp_o.gnt) // gnt always known
    `ASSERT_KNOWN_IF(MemIfAddrKnown_A,          mem_req_i.addr, mem_req_i.req) // addr known when req is asserted
    `ASSERT_KNOWN_IF(MemIfWeKnown_A,            mem_req_i.we,   mem_req_i.req) // 'we' known when req is asserted
    `ASSERT_KNOWN_IF(MemIfDataKnown_A,          mem_req_i.data, mem_req_i.req && mem_req_i.we) // data known when req and we are asserted (though arguably data where req.be is not asserted can be undefined, it is unlikely to be relevant)
    `ASSERT_KNOWN_IF(MemIfBeKnown_A,            mem_req_i.be,   mem_req_i.req && mem_req_i.we) // 'be' known when req and we are asserted

    `ASSERT_KNOWN_IF(MemIfRspErrValid_A,        mem_rsp_o.err,  $past(mem_req_i.req) && $past(mem_rsp_o.gnt));
    `ASSERT_KNOWN_IF(MemIfRspDataValid_A,       mem_rsp_o.data, $past(mem_req_i.req) && $past(mem_rsp_o.gnt));
endmodule
