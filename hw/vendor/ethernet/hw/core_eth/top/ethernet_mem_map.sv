// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_mem_map
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Split an incoming memory interface into four separate memory interfaces for:
- TX data buffer
- RX data buffer
- RX descriptor table
- CSRs

                Access  Base            Width       Depth (words)    Depth (bytes)   Note
CSRs            r/w     0x800           32 bits     0x10             0x80
TX buffer       wo      0x1000          64 bits     0x100            0x800           Maximum packet size is 0x5F2 bytes = 1522 bytes = 191 words = 0xbf
RX buffer       ro      0x4000          64 bits     0x400            0x2000          Space for 5.4 max-sized packets or 32 typically-sized packets
RX table        ro      0x6000          64 bits     0x8              0x40            8 entries for 8 packets, each entry is 64 bits (metadata for a packet)

This module currently wraps bus.sv which is taken from Ibex and has a couple of
known issues, but none of them are problematic for this implementation.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

`include "prim_assert.sv"

module ethernet_mem_map (
    input   logic            clk_i,
    input   logic            rst_ni,

    // Host interface
    input  mem_if_utils_pkg::mem_req_t      main_mem_req_i,
    output mem_if_utils_pkg::mem_rsp_t      main_mem_rsp_o,

    // Memory for RX buffer
    output mem_if_utils_pkg::mem_req_t      rx_data_mem_req_o,
    input  mem_if_utils_pkg::mem_rsp_t      rx_data_mem_rsp_i,

    // Memory for TX buffer
    output mem_if_utils_pkg::mem_req_t      tx_data_mem_req_o,
    input  mem_if_utils_pkg::mem_rsp_t      tx_data_mem_rsp_i,

    // Memory for RX descriptor table
    output mem_if_utils_pkg::mem_req_t      rx_meta_mem_req_o,
    input  mem_if_utils_pkg::mem_rsp_t      rx_meta_mem_rsp_i,

    // Memory interface for registers
    output mem_if_utils_pkg::mem_req_t      reg_mem_req_o,
    input  mem_if_utils_pkg::mem_rsp_t      reg_mem_rsp_i
);
    localparam int DATA_W       = mem_if_utils_pkg::DATA_W;
    localparam int ADDR_W       = mem_if_utils_pkg::ADDR_W;
    localparam int DATA_W_BYTES = mem_if_utils_pkg::DATA_W_BYTES;

    logic reqs    [4];
    logic rvalids [4];

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) rvalids <= '{default: '0};
        else         rvalids <= reqs; // rvalid is required to lag reqs & gnts by one cycle. This bus requires gnt to always be given immediately. I don't even bother driving rvakud in my downstream designs, so let's drive it here
    end

    logic [ADDR_W-1:0]       addrs  [4];
    logic                    wes    [4];
    logic                    errs   [4];
    logic                    gnts   [4];
    logic [DATA_W_BYTES-1:0] bes    [4];
    logic [DATA_W-1:0]       wdatas [4];
    logic [DATA_W-1:0]       rdatas [4];

    // Read data lines
    assign rdatas = {  reg_mem_rsp_i.data , tx_data_mem_rsp_i.data , rx_data_mem_rsp_i.data , rx_meta_mem_rsp_i.data };

    // Error lines (one bit each)
    assign errs   = {  reg_mem_rsp_i.err  , tx_data_mem_rsp_i.err  , rx_data_mem_rsp_i.err  , rx_meta_mem_rsp_i.err  };

    // Grant lines (one bit each)
    assign gnts   = {  reg_mem_rsp_i.gnt  , tx_data_mem_rsp_i.gnt  , rx_data_mem_rsp_i.gnt  , rx_meta_mem_rsp_i.gnt  };

    // Request lines
    assign reg_mem_req_o.req       = reqs[0];
    assign tx_data_mem_req_o.req   = reqs[1];
    assign rx_data_mem_req_o.req   = reqs[2];
    assign rx_meta_mem_req_o.req   = reqs[3];

    // Address lines
    assign reg_mem_req_o.addr      = addrs[0];
    assign tx_data_mem_req_o.addr  = addrs[1];
    assign rx_data_mem_req_o.addr  = addrs[2];
    assign rx_meta_mem_req_o.addr  = addrs[3];

    // Write-enable lines (one bit)
    assign reg_mem_req_o.we        = wes[0];
    assign tx_data_mem_req_o.we    = wes[1];
    assign rx_data_mem_req_o.we    = wes[2];
    assign rx_meta_mem_req_o.we    = wes[3];

    // Byte-enable lines (one bit per byte)
    assign reg_mem_req_o.be        = bes[0];
    assign tx_data_mem_req_o.be    = bes[1];
    assign rx_data_mem_req_o.be    = bes[2];
    assign rx_meta_mem_req_o.be    = bes[3];

    // Write data lines
    assign reg_mem_req_o.data      = wdatas[0];
    assign tx_data_mem_req_o.data  = wdatas[1];
    assign rx_data_mem_req_o.data  = wdatas[2];
    assign rx_meta_mem_req_o.data  = wdatas[3];

    // these have to be an unpacked types or SystemVerilog will be upset
    logic               main_gnt   [1];
    logic [DATA_W-1:0]  main_rdata [1];
    logic               main_err   [1];
    assign main_mem_rsp_o.gnt   = main_gnt[0];
    assign main_mem_rsp_o.data  = main_rdata[0];
    assign main_mem_rsp_o.err   = main_err[0];


    // Instantiate standard memory mapper bus (from Ibex)
    bus #(
        .NrDevices     (4),
        .NrHosts       (1),
        .DataWidth     (DATA_W),
        .AddressWidth  (ADDR_W)
    ) bus_inst (
        .clk_i                 (clk_i),
        .rst_ni                (rst_ni),

        .host_req_i            ({main_mem_req_i.req}),
        .host_addr_i           ({main_mem_req_i.addr & 64'h0000_0000_0000_FFFF}), // mask off upper bits since they aren't used for this
        .host_we_i             ({main_mem_req_i.we}),
        .host_be_i             ({main_mem_req_i.be}),
        .host_wdata_i          ({main_mem_req_i.data}),
        .host_rvalid_o         (), // not used by my interface, it assumes we are valid the cycle after req&gnt
        .host_gnt_o            (main_gnt),
        .host_rdata_o          (main_rdata),
        .host_err_o            (main_err),

        .device_req_o          (reqs),
        .device_addr_o         (addrs),
        .device_we_o           (wes),
        .device_be_o           (bes),
        .device_gnt_i          (gnts),
        .device_wdata_o        (wdatas),
        .device_rdata_i        (rdatas),
        .device_err_i          (errs),

        //                         CSR Address space \/     TX buffer address space \/    RX buffer address space \/   RX metadata address space \/
        .cfg_device_addr_base  ({  64'h0000_0000_0000_0800  ,   64'h0000_0000_0000_1000  ,   64'h0000_0000_0000_4000  ,   64'h0000_0000_0000_6000      }),
        .cfg_device_addr_mask  ({~(64'h0000_0000_0000_007F) , ~(64'h0000_0000_0000_07FF) , ~(64'h0000_0000_0000_1FFF) , ~(64'h0000_0000_0000_003F)     }),
        .device_rvalid_i       (rvalids)
    );

    ////////////////
    // Assertions //
    ////////////////
    // The bus instantiated above doesn't support wait states, so the downstream devices must always grant immediately. Asserting this just to be sure
    `ASSERT(GntAlwaysGiven_CSR_A,     reg_mem_req_o.req     -> reg_mem_rsp_i.gnt        );
    `ASSERT(GntAlwaysGiven_TX_data_A, tx_data_mem_req_o.req -> tx_data_mem_rsp_i.gnt    );
    `ASSERT(GntAlwaysGiven_RX_data_A, rx_data_mem_req_o.req -> rx_data_mem_rsp_i.gnt    );
    `ASSERT(GntAlwaysGiven_RX_meta_A, rx_meta_mem_req_o.req -> rx_meta_mem_rsp_i.gnt    );

    // Assert the host interface behaves correctly
    mem_if_assertions u_mem_if_assertions (
        .clk_i,
        .rst_ni,
        .mem_req_i(main_mem_req_i),
        .mem_rsp_o(main_mem_rsp_o)
    );

    // the other interfaces have similar assertions in their respective downstream modules, so I won't bother asserting them here
endmodule
