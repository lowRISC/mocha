// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_top_axi
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Wraps ethernet_top and adapts the memory interface to an AXI interface.
The user should pass the AXI struct types in as parameters - they should the
AXI struct types defined by the Pulp AXI platform.

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
This module is a testbench top level with a comprehensive CocoTB test suite
See coco_top.py and models.py for details of the testbench
The tests are intended to be invoked via FuseSoC, which will invoke CocoTB and
Verilator. Test results are written to "coco.log".

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
ethernet_top_axi #(
    .TARGET(TARGET),
    .axi_req_t(axi_req_t),
    .axi_rsp_t(axi_rsp_t)
) dut (
    .clk_125M_i        (),
    .clk_125M_quad_i   (),
    .clk_200M_i        (),
    .rst_ni            (),
    .axi_req_i         (),
    .axi_rsp_o         (),
    .ethernet_irq_o    (),
    .phy_reset_no      (),
    .eth_rgmii_rx_i    (),
    .eth_rgmii_tx_o    (),
    .eth_rgmii_mdio_i  (),
    .eth_rgmii_mdio_o  ()
);

*/

module ethernet_top_axi #(
    parameter TARGET         = "SIM", // "SIM", "GENERIC", "XILINX", or "ALTERA"
    parameter type axi_req_t = logic,
    parameter type axi_rsp_t = logic
) (
    // Clocking and reset
    input logic clk_125M_i,       // 125 MHz ethernet in-phase clock
    input logic clk_125M_quad_i,  // 125 MHz ethernet quadrature clock
    input logic clk_200M_i,       // 200 MHz IDELAYCTRL reference clock
    input logic rst_ni,           // Ethernet MAC reset, deassertion synchronous to clk_125M_i

    // AXI device interface
    input  axi_req_t axi_req_i,
    output axi_rsp_t axi_rsp_o,

    // Interrupt out
    output logic ethernet_irq_o,

    // RGMII signals to ethernet PHY
    output logic                                phy_reset_no, // Active low reset to PHY (note: "no" is not short for "number"; it's 'n' for active-low and 'o' for output)
    input  ethernet_pkg::eth_rgmii_rx_t         eth_rgmii_rx_i,
    output ethernet_pkg::eth_rgmii_tx_t         eth_rgmii_tx_o,
    input  ethernet_pkg::eth_rgmii_mdio_in_t    eth_rgmii_mdio_i,
    output ethernet_pkg::eth_rgmii_mdio_out_t   eth_rgmii_mdio_o
);
    // Memory interface to ethernet MAC
    mem_if_utils_pkg::mem_req_t eth_mem_req;
    mem_if_utils_pkg::mem_rsp_t eth_mem_rsp;

    logic eth_rvalid;
    always_ff @ (posedge clk_125M_i or negedge rst_ni) begin
        if (!rst_ni)    eth_rvalid <= 1'b0;
        else            eth_rvalid <= eth_mem_rsp.gnt && eth_mem_req.req;
    end

    // AXI to memory interface
    axi_to_detailed_mem #(
        .axi_req_t    ( axi_req_t    ),
        .axi_resp_t   ( axi_rsp_t    ),
        .AddrWidth    ( 64           ),
        .DataWidth    ( 64           ),
        .IdWidth      ( 4            ),
        .UserWidth    ( 1            ),
        .NumBanks     ( 1            )
    ) i_axi_to_detailed_mem (
        .clk_i           ( clk_125M_i       ),
        .rst_ni          ( rst_ni           ),
        .busy_o          (),
        .axi_req_i       ( axi_req_i        ),
        .axi_resp_o      ( axi_rsp_o        ),
        .mem_req_o       ( eth_mem_req.req  ),
        .mem_gnt_i       ( eth_mem_rsp.gnt  ),
        .mem_addr_o      ( eth_mem_req.addr ),
        .mem_wdata_o     ( eth_mem_req.data ),
        .mem_strb_o      ( eth_mem_req.be   ),
        .mem_atop_o      (), // ignored
        .mem_lock_o      (), // ignored
        .mem_we_o        ( eth_mem_req.we   ),
        .mem_id_o        (), // ignored
        .mem_user_o      (), // ignored
        .mem_cache_o     (), // ignored
        .mem_prot_o      (), // ignored
        .mem_qos_o       (), // ignored
        .mem_region_o    (), // ignored
        .mem_cheri_tag_o (), // ignored
        .mem_rvalid_i    ( eth_rvalid       ),
        .mem_rdata_i     ( eth_mem_rsp.data ),
        .mem_err_i       ( eth_mem_rsp.err  ),
        .mem_exokay_i    ('0), // drive to zero because mem_lock_o is not used
        .mem_cheri_tag_i ('0) // not using Cheri stuff
    );

    //////////////////////////////
    // Instantiate ethernet_top //
    //////////////////////////////
    ethernet_top #(
        .TARGET(TARGET)
    ) ethernet_top_inst (
        // Clocking and reset
        .clk_125M_i        (clk_125M_i),        // Main clock - used by memory interface and as 125 MHz ethernet in-phase clock
        .rst_ni            (rst_ni),            // Main reset, deassertion synchronous to clk_125M_i
        .clk_125M_quad_i   (clk_125M_quad_i),   // 125 MHz ethernet quadrature clock (used by MAC)
        .clk_200M_i        (clk_200M_i),        // 200 MHz IDELAYCTRL reference clock
        .mem_req_i         (eth_mem_req),       // Synchronous to clk_125M_i
        .mem_rsp_o         (eth_mem_rsp),       // Synchronous to clk_125M_i
        .phy_reset_no      (phy_reset_no),
        .eth_rgmii_rx_i    (eth_rgmii_rx_i),
        .eth_rgmii_tx_o    (eth_rgmii_tx_o),
        .eth_rgmii_mdio_i  (eth_rgmii_mdio_i),
        .eth_rgmii_mdio_o  (eth_rgmii_mdio_o),
        .irq_o             (ethernet_irq_o)
    );
endmodule
