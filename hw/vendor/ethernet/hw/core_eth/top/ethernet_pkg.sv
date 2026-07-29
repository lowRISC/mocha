// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_pkg
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Package of types and constants for the Ethernet IP.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
N/A

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
N/A

*/

package ethernet_pkg;
    // Constants
    localparam int MAX_ETH_PKT_LEN = 1522; // maximum Ethernet packet length in bytes
    typedef logic [$clog2(MAX_ETH_PKT_LEN)-1:0] pkt_len_t;

    localparam logic [31:0] VENDOR_ID = 32'h6C525343; // "lRSC" in ASCII
    localparam logic [31:0] DEVICE_ID = 32'h45544858; // "ETHX" in ASCII (X for AXI, there as a placeholder to allow alternate top-levels in future)
    localparam logic [31:0] MAGIC_NUM = 32'h4720abe4; // random magic number to identify the build

    ////////////////////////////
    // RX packet table params //
    ////////////////////////////
    localparam RX_DESC_TABLE_WIDTH = 64;
    localparam RX_DESC_TABLE_DEPTH = 8; // number of packets to buffer

    localparam RX_DESC_TABLE_BYTES     = RX_DESC_TABLE_DEPTH*RX_DESC_TABLE_WIDTH/8;
    localparam RX_DESC_TABLE_ADDR_MSBS = $clog2(RX_DESC_TABLE_DEPTH);
    localparam RX_DESC_TABLE_ADDR_W    = $clog2(RX_DESC_TABLE_BYTES);   // byte address width
    localparam RX_DESC_TABLE_ADDR_LSBS = $clog2(RX_DESC_TABLE_WIDTH/8); // number of LSbs to ignore for word addressing

    ///////////////////////////
    // RX data buffer params //
    ///////////////////////////
    localparam RX_DATA_BUF_WIDTH = 64;
    localparam RX_DATA_BUF_DEPTH = 1024;

    localparam RX_DATA_BUF_BYTES     = RX_DATA_BUF_DEPTH*RX_DATA_BUF_WIDTH/8;
    localparam RX_DATA_BUF_ADDR_MSBS = $clog2(RX_DATA_BUF_DEPTH);
    localparam RX_DATA_BUF_ADDR_W    = $clog2(RX_DATA_BUF_BYTES);   // byte address width
    localparam RX_DATA_BUF_ADDR_LSBS = $clog2(RX_DATA_BUF_WIDTH/8); // number of LSbs to ignore for word addressing

    ///////////////////////////
    // TX data buffer params //
    ///////////////////////////
    localparam TX_DATA_BUF_WIDTH = 64;
    localparam TX_DATA_BUF_DEPTH = 256; // 256 words of 64 bits = 2048 bytes, enough for one max-sized packet

    localparam TX_DATA_BUF_BYTES     = TX_DATA_BUF_DEPTH*TX_DATA_BUF_WIDTH/8;
    localparam TX_DATA_BUF_ADDR_MSBS = $clog2(TX_DATA_BUF_DEPTH);
    localparam TX_DATA_BUF_ADDR_W    = $clog2(TX_DATA_BUF_BYTES);   // byte address width
    localparam TX_DATA_BUF_ADDR_LSBS = $clog2(TX_DATA_BUF_WIDTH/8); // number of LSbs to ignore for word addressing

    ///////////////////////////////
    // CSRs address space params //
    ///////////////////////////////
    localparam CSR_WIDTH = 32;
    localparam CSR_DEPTH = 32; // number of 32-bit registers. 32 is probably plenty

    localparam CSR_BYTES     = CSR_DEPTH*CSR_WIDTH/8;
    localparam CSR_ADDR_MSBS = $clog2(CSR_DEPTH);
    localparam CSR_ADDR_W    = $clog2(CSR_BYTES);   // byte address width
    localparam CSR_ADDR_LSBS = $clog2(CSR_WIDTH/8); // number of LSbs to ignore for word addressing

    // Enum: reason for capturing a packet
    typedef enum logic [1:0] {
        MAC_MATCHES     = 0,
        MAC_BROADCAST   = 1,
        MAC_MULTICAST   = 2,
        NON_MAC_MATCH   = 3
    } capture_reason_e;

    // Metadata for a captured packet
    typedef struct packed {
        capture_reason_e capture_reason; // reason for capturing this packet
        // Option to include more metadata:
        // timestamp, sequence number, other stuff from the Ethernet frame (e.g. VLAN tag, source MAC address)
    } pkt_metadata_t;

    // AXI Stream interface (one byte per beat)
    typedef struct packed {
        logic [7:0] data;
        logic       last;
        logic       valid;
        logic       user;
    } axis_t;

    ///////////////////////////
    // Config/status structs //
    ///////////////////////////

    // RX status signals
    typedef struct packed {
        logic [$clog2(RX_DESC_TABLE_DEPTH+1)-1:0] n_packets_in_rx_buf;
        logic empty;
        logic table_almost_full;
        logic table_full;
        logic buf_almost_full;
        logic pkt_lost_pulse; // pulses as an event whenever a packet is lost due to full buffer or full table
    } rx_status_t;

    // RX config signals
    typedef struct packed {
        logic [47:0] mac_addr; // MAC address to match for capturing packets
        logic promiscuous_mode; // whether to capture all packets regardless of MAC address
    } rx_config_t;

    // TX status signals
    typedef struct packed {
        logic busy;
        logic done_pulse;
    } tx_status_t;

    // TX config signals
    typedef struct packed {
        logic [10:0] packet_len;
    } tx_config_t;

    typedef struct packed {
        logic loopback;
    } mac_config_t;

    typedef struct packed {
        logic tx_busy;
    } mac_status_t;

    // RGMII interface for connecting Ethernet MAC to PHY
    typedef struct packed {
        logic       clk;
        logic       ctl;
        logic [3:0] d;
    } eth_rgmii_rx_t;

    typedef struct packed {
        logic        clk;
        logic        en;
        logic [3:0]  d;
    } eth_rgmii_tx_t;

    typedef logic eth_rgmii_mdio_in_t;

    typedef struct packed {
        logic o;
        logic oen;
        logic c;
    } eth_rgmii_mdio_out_t;
endpackage
