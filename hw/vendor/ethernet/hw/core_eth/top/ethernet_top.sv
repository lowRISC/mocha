// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_top
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Top-level Ethernet framer module. Instantiates the MAC, RX framing, TX framing,
and CSR blocks, as well as handling the memory interface for each one.

Exposes an RGMII interface for connecting to the PHY and a memory interface for
accessing the TX data buffer, RX data buffer, RX metadata, and CSRs.

Also exposes an MDIO interface, but with dedicated 'in' and 'out' lines instead
of a tristate line. An 'output enable' line is provided to connect to a
tristate buffer, which is not included here as it is technology-dependent.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
Smoke tests are available for this module named ethernet_top_tb.sv.
It is also exercises in the ethernet_top_axi top, which has a (more
comprehensive) testbench of its own.
See README.md for more details.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
ethernet_top #(
    .TARGET(TARGET)
) ethernet_top_inst (
    // Clocking and reset
    .clk_125M_i        (),   // Main clock - used by memory interface and as 125 MHz ethernet in-phase clock
    .rst_ni            (),   // Main reset, deassertion synchronous to clk_125M_i
    .clk_125M_quad_i   (),   // 125 MHz ethernet quadrature clock (used by MAC)
    .clk_200M_i        (),   // 200 MHz IDELAYCTRL reference clock
    .mem_req_i         (),   // Synchronous to clk_125M_i
    .mem_rsp_o         (),   // Synchronous to clk_125M_i
    .phy_reset_no      (),
    .eth_rgmii_rx_i    (),
    .eth_rgmii_tx_o    (),
    .eth_rgmii_mdio_i  (),
    .eth_rgmii_mdio_o  (),
    .irq_o             ()
);

*/

module ethernet_top #(
    parameter TARGET = "SIM" // "SIM", "GENERIC", "XILINX", or "ALTERA"
) (
    // Clocking and reset
    input  logic                                clk_125M_i,       // Main clock - used by memory interface and as 125 MHz ethernet in-phase clock
    input  logic                                rst_ni,           // Main reset - asynchronous assertion, deassertion synchronous to clk_125m_i

    input  logic                                clk_125M_quad_i,  // 125 MHz ethernet quadrature clock (used by MAC)
    input  logic                                clk_200M_i,       // 200 MHz IDELAYCTRL reference clock

    // Main memory interface
    input  mem_if_utils_pkg::mem_req_t          mem_req_i,   // Synchronous to clk_125M_i
    output mem_if_utils_pkg::mem_rsp_t          mem_rsp_o,   // Synchronous to clk_125M_i

    // RGMII signals (connects Ethernet PHY to MAC)
    output logic                                phy_reset_no, // Active low reset to PHY (note: "no" is not short for "number"; it's 'n' for active-low and 'o' for output)
    input  ethernet_pkg::eth_rgmii_rx_t         eth_rgmii_rx_i,
    output ethernet_pkg::eth_rgmii_tx_t         eth_rgmii_tx_o,
    input  ethernet_pkg::eth_rgmii_mdio_in_t    eth_rgmii_mdio_i,
    output ethernet_pkg::eth_rgmii_mdio_out_t   eth_rgmii_mdio_o,

    // IRQ lines
    output logic                                irq_o // Synchronous to clk_125M_i
);
    //////////////////
    // Declarations //
    //////////////////

    // Connect the MAC to the RX and TX framing modules
    // AXI Stream interface
    ethernet_pkg::axis_t rx_axis_real,rx_axis_muxed;
    ethernet_pkg::axis_t tx_axis;
    logic tx_axis_tready; // backpressure for TX
    // there is no backpressure allowed for RX

    // Connect RX framing to CSR block
    ethernet_pkg::rx_config_t rx_config;
    ethernet_pkg::rx_status_t rx_status;
    logic rx_pop; // signal from CSR block to RX framing block to pop a packet

    // Connect TX framing to CSR block
    ethernet_pkg::tx_config_t tx_config;
    ethernet_pkg::tx_status_t tx_status;
    logic tx_kick; // signal from CSR block to TX framing block to kick off a transmission

    // Connect MAC to CSR block
    ethernet_pkg::mac_config_t mac_config;
    ethernet_pkg::mac_status_t mac_status;

    // Connect RX framing, TX framing, and CSR block to Memory Map
    mem_if_utils_pkg::mem_req_t rx_data_mem_req;  // Memory interface for RX data buffer
    mem_if_utils_pkg::mem_rsp_t rx_data_mem_rsp;
    mem_if_utils_pkg::mem_req_t rx_meta_mem_req;  // Memory interface for RX metadata (description table)
    mem_if_utils_pkg::mem_rsp_t rx_meta_mem_rsp;
    mem_if_utils_pkg::mem_req_t tx_data_mem_req;  // Memory interface for TX data buffer
    mem_if_utils_pkg::mem_rsp_t tx_data_mem_rsp;
    mem_if_utils_pkg::mem_req_t reg_mem_req;      // Memory interface for registers (configuration and status)
    mem_if_utils_pkg::mem_rsp_t reg_mem_rsp;

    // Instantiate MAC
    mac_wrapper #(
        .TARGET(TARGET)
    ) mac_wrapper_inst (
        // Clocks and resets
        .clk_125M_i       (clk_125M_i),
        .rst_ni           (rst_ni),
        .clk_125M_quad_i  (clk_125M_quad_i),
        .clk_200M_i       (clk_200M_i),
        .phy_reset_no     (phy_reset_no),
        // Config/status
        .mac_status_o     (mac_status),
        .mac_config_i     (mac_config),
        // RGMII interfaces
        .rgmii_rx_i       (eth_rgmii_rx_i),
        .rgmii_tx_o       (eth_rgmii_tx_o),
        // AXI Stream interfaces
        .tx_axis_i        (tx_axis),
        .tx_axis_tready_o (tx_axis_tready),
        .rx_axis_o        (rx_axis_real)
    );

    // Instantiate CSR block
    ethernet_csr csr_inst (
        .clk_i                          (clk_125M_i         ),
        .rst_ni                         (rst_ni             ),
        .mem_req_i                      (reg_mem_req        ),
        .mem_rsp_o                      (reg_mem_rsp        ),
        .mac_config_o                   (mac_config         ),
        .mac_status_i                   (mac_status         ),
        .rx_config_o                    (rx_config          ),
        .rx_status_i                    (rx_status          ),
        .rx_pop_o                       (rx_pop             ),
        .tx_config_o                    (tx_config          ),
        .tx_status_i                    (tx_status          ),
        .tx_kick_o                      (tx_kick            ),
        .eth_rgmii_mdio_i               (eth_rgmii_mdio_i   ),
        .eth_rgmii_mdio_o               (eth_rgmii_mdio_o   ),
        .irq_o                          (irq_o              )
    );

    ethernet_mem_map mem_map_inst (
        .clk_i              (clk_125M_i      ),
        .rst_ni             (rst_ni          ),
        .main_mem_req_i     (mem_req_i       ),
        .main_mem_rsp_o     (mem_rsp_o       ),
        .rx_data_mem_req_o  (rx_data_mem_req ),
        .rx_data_mem_rsp_i  (rx_data_mem_rsp ),
        .rx_meta_mem_req_o  (rx_meta_mem_req ),
        .rx_meta_mem_rsp_i  (rx_meta_mem_rsp ),
        .tx_data_mem_req_o  (tx_data_mem_req ),
        .tx_data_mem_rsp_i  (tx_data_mem_rsp ),
        .reg_mem_req_o      (reg_mem_req     ),
        .reg_mem_rsp_i      (reg_mem_rsp     )
    );

    // Instantiate TX framing
    ethernet_tx_framing tx_framing_inst(
        .clk_i                  (clk_125M_i     ),
        .rst_ni                 (rst_ni         ),
        .tx_axis_o              (tx_axis        ),
        .tx_axis_tready_i       (tx_axis_tready ), // backpressure from MAC (legal for TX, not for RX)
        .data_buf_mem_req_i     (tx_data_mem_req), // connects to the memory map
        .data_buf_mem_rsp_o     (tx_data_mem_rsp), // connects to the memory map
        .tx_status_o            (tx_status      ), // connects to CSR block
        .tx_config_i            (tx_config      ), // connects to CSR block
        .kick_tx_i              (tx_kick        )  // connects to CSR block
    );

    // Instantiate RX framing
    ethernet_rx_framing rx_framing_inst (
        .clk_i                  (clk_125M_i     ),
        .rst_ni                 (rst_ni         ),
        .rx_axis_i              (rx_axis_muxed  ), // connects to MAC output
        .data_buf_mem_req_i     (rx_data_mem_req), // connects to the memory map
        .data_buf_mem_rsp_o     (rx_data_mem_rsp), // connects to the memory map
        .desc_table_mem_req_i   (rx_meta_mem_req), // connects to the memory map
        .desc_table_mem_rsp_o   (rx_meta_mem_rsp), // connects to the memory map
        .rx_status_o            (rx_status      ), // connects to CSR block
        .rx_config_i            (rx_config      ), // connects to CSR block
        .pop_pkt_i              (rx_pop         )  // connects to CSR block
    );

    // Instantiate the loopback MUX
    ethernet_loopback loopback_mux (
        .clk_i          (clk_125M_i         ),
        .rst_ni         (rst_ni             ),
        .loopback_en    (mac_config.loopback), // select between TX and RX for loopback
        .axis_tx_ready_i(tx_axis_tready     ), // ready line to the TX AXI Stream - here it is used as an input so the MUX knows when a beat has been accepted. This only works because there is no backpressure on the RX side of this
        .axis_tx_i      (tx_axis            ), // AXI Stream from TX framing
        .axis_rx_real_i (rx_axis_real       ), // AXI Stream from MAC RX output
        .axis_o         (rx_axis_muxed      )  // Multiplexed AXI stream
    );
endmodule
