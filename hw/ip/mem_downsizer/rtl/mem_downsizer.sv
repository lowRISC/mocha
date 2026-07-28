// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// 2:1 downsizer for simple memory interface
// Issues two downstream requests for each upstream requests
// then concatenates the response (if there are any)
// Allows maximum throughput on the downstream interface (which is half throughput for the upstream interface)
// If CUT is disabled, latency is minimised - transaction pass straight through if another transaction is not in progress
// To ease timing, CUT can be set to introduce a pipeline stage to the upstream interface

`include "prim_assert.sv"

module mem_downsizer #(
    parameter  bit CUT = 1'b0, // If true, cut the upstream interface to ease timing
    parameter  int UPSTREAM_DATA_W = -1,
    parameter  int ADDR_W = -1,

    localparam int DOWNSTREAM_DATA_W = UPSTREAM_DATA_W / 2,
    localparam int UPSTREAM_BYTES = UPSTREAM_DATA_W / 8,
    localparam int DOWNSTREAM_BYTES = DOWNSTREAM_DATA_W / 8
) (
    // Clocking and reset
    input  logic clk_i,
    input  logic rst_ni,

    // Memory request in
    input  logic                        mem_req_i,
    output logic                        mem_gnt_o,
    input  logic                        mem_we_i,
    input  logic [  UPSTREAM_BYTES-1:0] mem_be_i,
    input  logic [          ADDR_W-1:0] mem_addr_i,
    input  logic [ UPSTREAM_DATA_W-1:0] mem_wdata_i,
    output logic                        mem_rvalid_o,
    output logic [ UPSTREAM_DATA_W-1:0] mem_rdata_o,

    // Memory request out
    output logic                         mem_req_o,
    input  logic                         mem_gnt_i,
    output logic                         mem_we_o,
    output logic [ DOWNSTREAM_BYTES-1:0] mem_be_o,
    output logic [           ADDR_W-1:0] mem_addr_o,
    output logic [DOWNSTREAM_DATA_W-1:0] mem_wdata_o,
    input  logic                         mem_rvalid_i,
    input  logic [DOWNSTREAM_DATA_W-1:0] mem_rdata_i
);
    // Conveniently, the logic for sending a request and receiving a response
    // can be handled completely independently. Even if a device does not support
    // multiple outstanding requests, the downsizer doesn't have to worry about
    // this as the device should simply assert appropriate backpressure

    // Accordingly this module instantiates three submodules:
    // 1. A cut module to cut combo paths on the upstream interface. This is bypassed if CUT is false
    // 2. A request downsizer module which accepts upstream requests and generates two downstream requests at addresses separated by DOWNSTREAM_BYTES
    // 3. A response downsizer module which accepts downstream responses and concatenates them into a single upstream response

    logic                       mem_cut_req;
    logic                       mem_cut_gnt;
    logic                       mem_cut_we;
    logic [ UPSTREAM_BYTES-1:0] mem_cut_be;
    logic [         ADDR_W-1:0] mem_cut_addr;
    logic [UPSTREAM_DATA_W-1:0] mem_cut_wdata;
    logic                       mem_cut_rvalid;
    logic [UPSTREAM_DATA_W-1:0] mem_cut_rdata;
    generate if (CUT) begin : gen_cut
        mem_cut #(
            .DATA_W (UPSTREAM_DATA_W),
            .ADDR_W (ADDR_W)
        ) req_cut (
            .clk_i          (clk_i          ),
            .rst_ni         (rst_ni         ),

            .req_i          (mem_req_i    ),
            .gnt_o          (mem_gnt_o    ),
            .we_i           (mem_we_i     ),
            .be_i           (mem_be_i     ),
            .addr_i         (mem_addr_i   ),
            .wdata_i        (mem_wdata_i  ),
            .rvalid_o       (mem_rvalid_o ),
            .rdata_o        (mem_rdata_o  ),

            .req_o          (mem_cut_req    ),
            .gnt_i          (mem_cut_gnt    ),
            .we_o           (mem_cut_we     ),
            .be_o           (mem_cut_be     ),
            .addr_o         (mem_cut_addr   ),
            .wdata_o        (mem_cut_wdata  ),
            .rvalid_i       (mem_cut_rvalid ),
            .rdata_i        (mem_cut_rdata  )
        );
    end else begin : gen_no_cut
        assign mem_cut_req    = mem_req_i;
        assign mem_gnt_o      = mem_cut_gnt;
        assign mem_cut_we     = mem_we_i;
        assign mem_cut_be     = mem_be_i;
        assign mem_cut_addr   = mem_addr_i;
        assign mem_cut_wdata  = mem_wdata_i;
        assign mem_rvalid_o   = mem_cut_rvalid;
        assign mem_rdata_o    = mem_cut_rdata;
    end endgenerate

    mem_req_downsizer #(
        .UPSTREAM_DATA_W (UPSTREAM_DATA_W),
        .ADDR_W(ADDR_W)
    ) req_downsizer (
        .clk_i        (clk_i          ),
        .rst_ni       (rst_ni         ),

        .mem_req_i    (mem_cut_req    ),
        .mem_gnt_o    (mem_cut_gnt    ),
        .mem_we_i     (mem_cut_we     ),
        .mem_be_i     (mem_cut_be     ),
        .mem_addr_i   (mem_cut_addr   ),
        .mem_wdata_i  (mem_cut_wdata  ),

        .mem_req_o    (mem_req_o    ),
        .mem_gnt_i    (mem_gnt_i    ),
        .mem_we_o     (mem_we_o     ),
        .mem_be_o     (mem_be_o     ),
        .mem_addr_o   (mem_addr_o   ),
        .mem_wdata_o  (mem_wdata_o  )
    );

    mem_rsp_downsizer #(
        .UPSTREAM_DATA_W (UPSTREAM_DATA_W)
    ) rsp_downsizer (
        .clk_i        (clk_i            ),
        .rst_ni       (rst_ni           ),
        .mem_rvalid_o (mem_cut_rvalid ),
        .mem_rdata_o  (mem_cut_rdata  ),
        .mem_rvalid_i (mem_rvalid_i   ),
        .mem_rdata_i  (mem_rdata_i    )
    );

    ////////////////
    // Assertions //
    ////////////////
    int n_granted_rds;
    int n_completed;
    always @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            n_granted_rds <= 0;
            n_completed   <= 0;
        end else begin
            if (mem_req_i && mem_gnt_o) n_granted_rds <= n_granted_rds + 1;
            if (mem_rvalid_o)             n_completed   <= n_completed + 1;
        end
    end
    `ASSERT(NoSpuriousResponses_A, n_completed <= n_granted_rds)

    // Assert output values are known
    `ASSERT_KNOWN(RvalidKnown_A,  mem_rvalid_o)
    `ASSERT_KNOWN_IF(ReadDataKnown_A,  mem_rdata_o, mem_rvalid_o)
    `ASSERT_KNOWN(ReqKnown_A,    mem_req_o)
    `ASSERT_KNOWN(GrantKnown_A,  mem_gnt_o)
    `ASSERT_KNOWN_IF(WriteEnableKnown_A,  mem_we_o,    mem_req_o)
    `ASSERT_KNOWN_IF(ByteEnableKnown_A,   mem_be_o,    mem_req_o)
    `ASSERT_KNOWN_IF(AddressKnown_A,      mem_addr_o,  mem_req_o)
    `ASSERT_KNOWN_IF(WriteDataKnown_A,    mem_wdata_o, mem_req_o)
endmodule

/* verilator lint_off DECLFILENAME */
module mem_req_downsizer #(
    parameter  int UPSTREAM_DATA_W = -1,
    parameter  int ADDR_W = -1,
    localparam int DOWNSTREAM_DATA_W = UPSTREAM_DATA_W / 2,

    localparam int UPSTREAM_BYTES = UPSTREAM_DATA_W / 8,
    localparam int DOWNSTREAM_BYTES = DOWNSTREAM_DATA_W / 8
) (
    // Clocking and reset
    input  logic clk_i,
    input  logic rst_ni,

    // Memory request in
    input  logic                        mem_req_i,
    output logic                        mem_gnt_o,
    input  logic                        mem_we_i,
    input  logic [ UPSTREAM_BYTES-1:0]  mem_be_i,
    input  logic [         ADDR_W-1:0]  mem_addr_i,
    input  logic [UPSTREAM_DATA_W-1:0]  mem_wdata_i,

    // Memory request out
    output logic                            mem_req_o,
    input  logic                            mem_gnt_i,
    output logic                            mem_we_o,
    output logic [ DOWNSTREAM_BYTES-1:0]    mem_be_o,
    output logic [           ADDR_W-1:0]    mem_addr_o,
    output logic [DOWNSTREAM_DATA_W-1:0]    mem_wdata_o
);
    // When a request comes in we pass it through to the downstream interface
    // but do not grant the upstream request until BOTH downstream requests have
    // been granted. This avoids the needs for any buffering of the request data
    logic in_progress;
    // indicates that the first of two downstream requests has been granted
    // therefore when it is deasserted we should be passing through the first request
    // and when it is asserted we should be passing through the second request

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)                     in_progress <= 1'b0;
        else if (mem_req_o && mem_gnt_i) in_progress <= !in_progress;
    end
    assign mem_req_o = mem_req_i;

    // We grant the upstream request when the handshake occurs on the SECOND downstream request
    assign mem_gnt_o = mem_req_o && mem_gnt_i && in_progress;

    // We pass through the write enable, byte enables, address, and write data to the downstream interface
    assign mem_we_o     = mem_we_i;
    assign mem_be_o     = in_progress ? mem_be_i[2*DOWNSTREAM_BYTES-1:DOWNSTREAM_BYTES]         : mem_be_i[DOWNSTREAM_BYTES-1:0];
    assign mem_wdata_o  = in_progress ? mem_wdata_i[2*DOWNSTREAM_DATA_W-1:DOWNSTREAM_DATA_W]    : mem_wdata_i[DOWNSTREAM_DATA_W-1:0];
    assign mem_addr_o   = mem_addr_i + (ADDR_W)'(in_progress ? DOWNSTREAM_BYTES : 0); // add DOWNSTREAM_BYTES to the address for the second request
    // Inefficiency: we could skip the first request if its' a write and all byte enables are unset

    ////////////////
    // Assertions //
    ////////////////

    // Assert the req does not deassert until the gnt has been asserted
    // and that the associated request data is stable until the grant is asserted
    // assert these properties for both the upstream and downstream interfaces
    `ASSERT(UpstreamReqStaysUntilHandshake_A,       mem_req_i && !mem_gnt_o |=> mem_req_i );
    `ASSERT(DownstreamReqStaysUntilHandshake_A,     mem_req_o && !mem_gnt_i |=> mem_req_o );
    `ASSERT(UpstreamReqStableUntilHandshake_A,      mem_req_i && !mem_gnt_o |=> $stable({mem_wdata_i,mem_addr_i,mem_be_i,mem_we_i}) );
    `ASSERT(DownstreamReqStableUntilHandshake_A,    mem_req_o && !mem_gnt_i |=> $stable({mem_wdata_o,mem_addr_o,mem_be_o,mem_we_o}) );
endmodule

module mem_rsp_downsizer #(
    parameter  int UPSTREAM_DATA_W = -1,
    localparam int DOWNSTREAM_DATA_W = UPSTREAM_DATA_W / 2
) (
    // Clocking and reset
    input  logic clk_i,
    input  logic rst_ni,

    // Memory response to upstream
    output logic                         mem_rvalid_o,
    output logic [UPSTREAM_DATA_W-1:0]   mem_rdata_o,

    // Memory response from downstream
    input  logic                         mem_rvalid_i,
    input  logic [DOWNSTREAM_DATA_W-1:0] mem_rdata_i
);
    /////////////////////////////////////
    // Logic for outgoing valid signal //
    /////////////////////////////////////

    // Every second pulse of mem_rvalid_i should pass through to mem_rvalid_o
    logic partially_read;

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)                              partially_read <= 1'b0;
        else if (mem_rvalid_i && !partially_read) partially_read <= 1'b1;
        else if (mem_rvalid_i && partially_read)  partially_read <= 1'b0;
    end
    assign mem_rvalid_o = mem_rvalid_i && partially_read;

    ///////////////////////////////////////
    // Logic for concatenating read word //
    ///////////////////////////////////////
    logic [DOWNSTREAM_DATA_W-1:0] lower_word;
    logic [DOWNSTREAM_DATA_W-1:0] upper_word;

    assign upper_word = mem_rdata_i; // upper word can be passed through
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)              lower_word <= '0;
        else if (mem_rvalid_i)    lower_word <= mem_rdata_i;
    end
    assign mem_rdata_o = (UPSTREAM_DATA_W)'(upper_word << DOWNSTREAM_DATA_W) | (UPSTREAM_DATA_W)'(lower_word);
endmodule

/* verilator lint_on DECLFILENAME */
