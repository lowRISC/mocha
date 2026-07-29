// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_rx_framing
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Filters incoming packets based on MAC address and stores the data in a ring
buffer. A descriptor table provides metadata for each packet, including the
packet length and a pointer to its location in the ring buffer. Packets can be
popped by asserting a pulse on pop_pkt_i, which will free the oldest packet in
the buffer.

Interfaces:
    - AXI-Stream input (rx_axis_i) - no backpressure. User-defined signal asserts to indicate that the whole packet is bad
    - Read-only memory interface for the data buffer (data_buf_mem_req_i, data_buf_mem_rsp_o)
    - Read-only memory interface for the descriptor table (desc_table_mem_req_i, desc_table_rsp_o)
    - Statuses (rx_status_o)
    - Configuration (rx_config_i)
    - Pulse to pop the oldest packet (pop_pkt_i)

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module but it is exercised by the
ethernet_top and ethernet_top_axi testbenches.

*/

`include "prim_assert.sv"

module ethernet_rx_framing (
    input  logic clk_i,
    input  logic rst_ni,

    // AXI-Stream input
    input  ethernet_pkg::axis_t     rx_axis_i,
    // backpressure is not allowed on the input stream

    // Memory for the data buffer
    input  mem_if_utils_pkg::mem_req_t data_buf_mem_req_i,
    output mem_if_utils_pkg::mem_rsp_t data_buf_mem_rsp_o,

    // Memory interface for the packet descriptors
    input  mem_if_utils_pkg::mem_req_t desc_table_mem_req_i,
    output mem_if_utils_pkg::mem_rsp_t desc_table_mem_rsp_o,

    // Statuses
    output ethernet_pkg::rx_status_t          rx_status_o,

    // Configuration
    input  ethernet_pkg::rx_config_t rx_config_i,
    input  logic       pop_pkt_i // pulse to pop oldest packet
);
    ///////////////////////////
    // Filter write requests //
    ///////////////////////////
    // Filter write requests to the data buffer and descriptor table (they are read-only from the software side)
    mem_if_utils_pkg::mem_req_t data_buf_mem_req_ro,desc_table_mem_req_ro;
    mem_if_utils_pkg::mem_rsp_t data_buf_mem_rsp_ro,desc_table_mem_rsp_ro;
    // mem_to_ro_mem takes a simple memory interface and blocks any write requests, responding to them immediately with an error response
    // read requests are passed straight through
    // it's mostly just combo logic
    mem_to_ro_mem data_buf_mem_to_ro (
        .clk_i, .rst_ni,
        .mem_req_i(data_buf_mem_req_i),
        .mem_rsp_o(data_buf_mem_rsp_o),
        .mem_req_o(data_buf_mem_req_ro),
        .mem_rsp_i(data_buf_mem_rsp_ro)
    );
    mem_to_ro_mem desc_table_mem_to_ro (
        .clk_i, .rst_ni,
        .mem_req_i(desc_table_mem_req_i),
        .mem_rsp_o(desc_table_mem_rsp_o),
        .mem_req_o(desc_table_mem_req_ro),
        .mem_rsp_i(desc_table_mem_rsp_ro)
    );
    logic unused;
    assign unused = ^{data_buf_mem_req_ro.data,data_buf_mem_req_ro.be,data_buf_mem_req_ro.we,desc_table_mem_req_ro.data,desc_table_mem_req_ro.be,desc_table_mem_req_ro.we};

    /////////////////////
    // Packet metadata //
    /////////////////////
    logic abandon_packet; // pulse to abandon this packet - won't necessarily be held for the whole packet, but if it is high at any point that is sufficient for the axis_pkt_ring_buffer to discard it
    ethernet_pkg::pkt_metadata_t current_pkt_metadata;
    ethernet_pkg::capture_reason_e capture_reason; // The reason for capturing this packet

    assign current_pkt_metadata.capture_reason  = capture_reason;
    // this gets sampled by the ring buffer at the end of the packet

    //////////////////////////
    // Feed the ring buffer //
    //////////////////////////
    ethernet_pkg::pkt_metadata_t                    read_if_pkt_metadata;
    logic [ethernet_pkg::RX_DATA_BUF_ADDR_W-1:0]    read_if_pkt_buf_addr;
    ethernet_pkg::pkt_len_t                         read_if_pkt_len;
    axis_pkt_ring_buffer #(
        .PACKET_INDEX_W             (ethernet_pkg::RX_DESC_TABLE_ADDR_MSBS),      // allow 8 packets in the buffer
        .BUF_ADDR_W                 (ethernet_pkg::RX_DATA_BUF_ADDR_W),           // allow 2^BUF_ADDR_W bytes in the buffer
        .MAX_PKT_LEN                (ethernet_pkg::MAX_ETH_PKT_LEN),
        .BufAlmostFullThreshold     (1524),                         // maximum ethernet packet is 1522 bytes = 190 words*64 bits/word
        .TableAlmostFullThreshold   (2),                            // raise the alarm when only two slots are left (out of 8)
        .metadata_t                 (ethernet_pkg::pkt_metadata_t)
    ) ring_buffer_inst (
        .clk_i,
        .rst_ni,

        // Packet input stream
        .pkt_tdata_i            (rx_axis_i.data                     ),
        .pkt_tvalid_i           (rx_axis_i.valid                    ),
        .pkt_tlast_i            (rx_axis_i.last                     ),

        .pkt_metadata_i         (current_pkt_metadata               ),
        .pkt_abandon_i          (abandon_packet                     ),

        // Descriptor table access
        .table_req_i            (desc_table_mem_req_ro.req          ),
        .table_index_i          (desc_table_mem_req_ro.addr[ethernet_pkg::RX_DESC_TABLE_ADDR_W-1:ethernet_pkg::RX_DESC_TABLE_ADDR_LSBS] ),
        .table_gnt_o            (desc_table_mem_rsp_ro.gnt          ),
        .table_err_o            (desc_table_mem_rsp_ro.err          ),
        .table_metadata_o       (read_if_pkt_metadata               ),
        .table_ptr_o            (read_if_pkt_buf_addr               ),
        .table_pkt_len_o        (read_if_pkt_len                    ),

        .table_pop_i            (pop_pkt_i                          ),

        // Data buffer access
        .buf_req_i              (data_buf_mem_req_ro.req            ),
        .buf_addr_i             (data_buf_mem_req_ro.addr[ethernet_pkg::RX_DATA_BUF_ADDR_W-1:0]         ), // cut off MSBs
        .buf_err_o              (data_buf_mem_rsp_ro.err            ),
        .buf_data_o             (data_buf_mem_rsp_ro.data           ),
        .buf_gnt_o              (data_buf_mem_rsp_ro.gnt            ),

        // Statuses
        .empty_o                (rx_status_o.empty                  ),
        .packet_lost_o          (rx_status_o.pkt_lost_pulse         ),
        .buf_almost_full_o      (rx_status_o.buf_almost_full        ),
        .table_full_o           (rx_status_o.table_full             ),
        .table_almost_full_o    (rx_status_o.table_almost_full      ),
        .n_pkts_buffered_o      (rx_status_o.n_packets_in_rx_buf    )
    );

    assign desc_table_mem_rsp_ro.data[15:0]   = (16)'(read_if_pkt_metadata);    // cast will just left-pad zeros
    assign desc_table_mem_rsp_ro.data[31:16]  = (16)'(read_if_pkt_len);         // cast will just left-pad zeros
    assign desc_table_mem_rsp_ro.data[63:32]  = (32)'(read_if_pkt_buf_addr);    // cast will just left-pad zeros

    ///////////////////
    // MAC filtering //
    ///////////////////
    // Uses tlast to know when a new packet is starting, then checks the first 6 bytes (which will be the destination MAC address, per the Ethernet spec)
    // to see if we should keep this packet
    // abandon_packet will go high on the same cycle as tvalid if the MAC address is no good
    // We also store capture_reason for later so it can be saved in the descriptor table

    mac_address_filter mac_address_filter_inst (
        .clk_i,
        .rst_ni,
        .rx_axis_i,
        .mac_addr_i(rx_config_i.mac_addr),
        .capture_reason_o(capture_reason)
    );

    // if the MAC doesn't match and we're not in promiscuous mode, we should drop the packet. Also drop if the CRC is bad
    assign abandon_packet = ((capture_reason == ethernet_pkg::NON_MAC_MATCH) && ~rx_config_i.promiscuous_mode) || (rx_axis_i.user && rx_axis_i.valid);

    ////////////////
    // Assertions //
    ////////////////
    // Assert the memory interfaces behave correctly
    mem_if_assertions data_buf_if_assertions (
        .clk_i,
        .rst_ni,
        .mem_req_i(data_buf_mem_req_i),
        .mem_rsp_o(data_buf_mem_rsp_o)
    );
    mem_if_assertions desc_table_if_assertions (
        .clk_i,
        .rst_ni,
        .mem_req_i(desc_table_mem_req_i),
        .mem_rsp_o(desc_table_mem_rsp_o)
    );

    // Assert outputs are known
    `ASSERT_KNOWN(EmptyFlagKnown_A,             rx_status_o.empty);
    `ASSERT_KNOWN(BufFullFlagKnown_A,           rx_status_o.pkt_lost_pulse);
    `ASSERT_KNOWN(BufAlmostFullFlagKnown_A,     rx_status_o.buf_almost_full);
    `ASSERT_KNOWN(TableFullFlagKnown_A,         rx_status_o.table_full);
    `ASSERT_KNOWN(TableAlmostFullFlagKnown_A,   rx_status_o.table_almost_full);

    // Assert behaviour under reset
    `ASSERT(RxDataBufGntLowAtReset_A,          !rst_ni |-> !data_buf_mem_rsp_o.gnt           , clk_i, 0);
    `ASSERT(RxStatusEmptyAtReset_A,            !rst_ni |->  rx_status_o.empty                , clk_i, 0);
    `ASSERT(RxStatusPktLostAtReset_A,          !rst_ni |-> !rx_status_o.pkt_lost_pulse       , clk_i, 0);
    `ASSERT(RxStatusBufAlmostfullAtReset_A,    !rst_ni |-> !rx_status_o.buf_almost_full      , clk_i, 0);
    `ASSERT(RxStatusTableFullAtReset_A,        !rst_ni |-> !rx_status_o.table_full           , clk_i, 0);
    `ASSERT(RxStatusTableAlmostFullAtReset_A,  !rst_ni |-> !rx_status_o.table_almost_full    , clk_i, 0);
    //                                                                                         ^ clk, ^ normally a reset to disable the assertion, but we want these to be true even under reset

endmodule
