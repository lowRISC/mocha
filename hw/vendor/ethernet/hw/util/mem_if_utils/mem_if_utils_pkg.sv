// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: mem_if_utils_pkg
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Package of types and constants for mem_if_utils modules. Defines a simple
memory interface with ready/gnt handshakes. See README.md for details including
sample waveforms and a protocol specification.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
N/A

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
N/A

*/

package mem_if_utils_pkg;
    //////////////////////////////////
    // Main memory interface params //
    //////////////////////////////////
    localparam ADDR_W = 64;
    localparam DATA_W_BYTES = 8;
    localparam DATA_W = 8*DATA_W_BYTES;

    //////////////////////////////////
    // Addressable memory interface //
    //////////////////////////////////
    typedef struct packed {
        logic                               req;  // requests a transaction
        logic                               we;   // write enable
        logic [DATA_W_BYTES-1:0]            be;   // byte enable (for writes)
        logic [ADDR_W-1:0]                  addr;
        logic [DATA_W-1:0]                  data;
    } mem_req_t;

    typedef struct packed {
        logic                      gnt;    // transaction is accepted. Response data will be given the next cycle
        logic [DATA_W-1:0]         data;   // read data
        logic                      err;    // error signal. Valid with rvalid. 'data' MAY be used to communicate error type
    } mem_rsp_t;

    // Simple memory interface with ready/gnt handshakes
    // 'err' and 'data' should be valid on the cycle FOLLOWING 'gnt && req'
    // NOT on the same cycle as 'gnt'
    // (This allows you to tie 'gnt' to 1 while still having pipelined single-cycle access)

    // 'be' is byte enables and is only meaningful for writes
    // addresses should always be byte addresses
    // The lower bits of the byte address are essentially ignored because 'be' is used for unaligned writes
endpackage
