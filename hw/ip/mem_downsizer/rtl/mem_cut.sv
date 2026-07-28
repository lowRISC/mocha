// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// mem_cut:
//   Cuts (pipelines) all combinational paths between upstream and downstream interface

module mem_cut #(
    parameter int DATA_W = 64,
    parameter int ADDR_W = 64
) (
    input clk_i,
    input rst_ni, // Active low reset. Assert asynchronously, deassert synchronously

    // Upstream interface
    input  logic                req_i,
    output logic                gnt_o,
    input  logic                we_i,
    input  logic [DATA_W/8-1:0] be_i,
    input  logic [ADDR_W-1:0]   addr_i,
    input  logic [DATA_W-1:0]   wdata_i,
    output logic                rvalid_o,
    output logic [DATA_W-1:0]   rdata_o,

    // Downstream interface
    output logic                req_o,
    input  logic                gnt_i,
    output logic                we_o,
    output logic [DATA_W/8-1:0] be_o,
    output logic [ADDR_W-1:0]   addr_o,
    output logic [DATA_W-1:0]   wdata_o,
    input  logic                rvalid_i,
    input  logic [DATA_W-1:0]   rdata_i
);
    typedef struct packed {
        logic                we_i;
        logic [DATA_W/8-1:0] be_i;
        logic [ADDR_W-1:0]   addr_i;
        logic [DATA_W-1:0]   wdata_i;
    } mem_req_t;

    mem_req_t incoming_req,outgoing_req;
    assign incoming_req.we_i    = we_i;
    assign incoming_req.be_i    = be_i;
    assign incoming_req.addr_i  = addr_i;
    assign incoming_req.wdata_i = wdata_i;
    assign we_o     = outgoing_req.we_i;
    assign be_o     = outgoing_req.be_i;
    assign addr_o   = outgoing_req.addr_i;
    assign wdata_o  = outgoing_req.wdata_i;

    // FIFO is necessary to ensure full throughput
    // though half throughput is possible with only a layer of flops
    prim_fifo_sync #(
        .Width             ( $bits(mem_req_t) ),
        .Pass              ( 1'b0 ), // to cut combo paths, disable pass-through mode
        .Depth             ( 2    ), // enough to ensure full throughput
        .OutputZeroIfEmpty ( 1    ),
        .NeverClears       ( 0    ),
        .Secure            ( 0    )
    ) u_prim_fifo_sync (
        .clk_i  (clk_i),
        .rst_ni (rst_ni),

        .clr_i    (1'b0),
        .wvalid_i (req_i),
        .wready_o (gnt_o),
        .wdata_i  (incoming_req),
        .rvalid_o (req_o),
        .rready_i (gnt_i),
        .rdata_o  (outgoing_req),
        .full_o   (),
        .depth_o  (),
        .err_o    ()
    );

    ///////////////////////
    // Response handling //
    ///////////////////////
    // because there is no backpressure on the response path, we can just flop it instead of handshaking through a FIFO
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rvalid_o    <= '0;
            rdata_o     <= '0;
        end else begin
            rvalid_o    <= rvalid_i;
            rdata_o     <= rdata_i;
        end
    end
endmodule
