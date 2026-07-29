/*

Copyright (c) 2014-2018 Alex Forencich
              2026 Modified by Thomas O'Dea for lowRISC C.I.C.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

Wrapper for rgmii_core

This:
    - Adds IO delay to physical i/o for timing closure

                                |--------------------------------------This module-------------------------------------------|
                                |                                                                                            |
                                |                                                                                            |
    |---------------|           |        |--------------|                                       |-------------------|        |                  |-------------------|
    |  TX Buffer(s) | ---AXI Stream--->  |  TX MAC      | ---RGMII (8-bits wide)------------->  |  TX PHY IF (ODDR) |  ---RGMII (4-bits DDR)--> | TX PHY (off-chip) | =========|
    |---------------|           |        |--------------|                                       |-------------------|        |                  |-------------------|          |
                                |                                                                                            |                                                 |
                                |                                                                                            |                                              Ethernet
                                |                                                                                            |                                               Cable
                                |                                                                                            |                                                 |
    |---------------|           |        |--------------|                                       |-------------------|        |                  |-------------------|          |
    |  RX Buffer(s) | <--AXI Stream----  |  RX MAC      | <--RGMII (8-bits wide)--------------  |  RX PHY IF (IDDR) |  <--RGMII (4-bits DDR)--0 | RX PHY (off-chip) | =========|
    |---------------|           |        |--------------|                                       |-------------------|        |                  |-------------------|
                                |                                                                                            |
                                |--------------------------------------------------------------------------------------------|
*/

`include "prim_assert.sv"

module rgmii_soc #
(
    // target (e.g. Xilinx FPGA, generic model, etc.)
    parameter TARGET = "SIM" // "SIM", "GENERIC", "XILINX", or "ALTERA"
) (
    // Internal 125 MHz clock
    input              clk_int,
    input              rst_int,
    input              clk90_int,
    input              clk_200_int,

    /*
     * Ethernet: 1000BASE-T RGMII
     */
    input wire         phy_rx_clk,
    input wire [3:0]   phy_rxd,
    input wire         phy_rx_ctl,
    output wire        phy_tx_clk,
    output wire [3:0]  phy_txd,
    output wire        phy_tx_ctl,
    output wire        phy_reset_n,
    output wire        mac_gmii_tx_en,

       /*
        * AXI input
        */
    input wire         tx_axis_tvalid,
    input wire         tx_axis_tlast,
    input wire [7:0]   tx_axis_tdata,
    output wire        tx_axis_tready,
    input wire         tx_axis_tuser,

       /*
        * AXI output
        */
    output wire [7:0]  rx_axis_tdata,
    output wire        rx_axis_tvalid,
    output wire        rx_axis_tlast,
    output             rx_axis_tuser
);

// IODELAY elements for RGMII interface to PHY
wire [3:0] phy_rxd_delay;
wire       phy_rx_ctl_delay;

generate if (TARGET == "XILINX") begin : gen_xilinx_target
    IDELAYCTRL
    idelayctrl_inst
    (
        .REFCLK(clk_200_int),
        .RST(rst_int),
        .RDY()
    );

    IDELAYE2 #(
        .IDELAY_TYPE("FIXED")
    )
    phy_rxd_idelay_0
    (
        .IDATAIN(phy_rxd[0]),
        .DATAOUT(phy_rxd_delay[0]),
        .DATAIN(1'b0),
        .C(1'b0),
        .CE(1'b0),
        .INC(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'd0),
        .CNTVALUEOUT(),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );

    IDELAYE2 #(
        .IDELAY_TYPE("FIXED")
    )
    phy_rxd_idelay_1
    (
        .IDATAIN(phy_rxd[1]),
        .DATAOUT(phy_rxd_delay[1]),
        .DATAIN(1'b0),
        .C(1'b0),
        .CE(1'b0),
        .INC(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'd0),
        .CNTVALUEOUT(),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );

    IDELAYE2 #(
        .IDELAY_TYPE("FIXED")
    )
    phy_rxd_idelay_2
    (
        .IDATAIN(phy_rxd[2]),
        .DATAOUT(phy_rxd_delay[2]),
        .DATAIN(1'b0),
        .C(1'b0),
        .CE(1'b0),
        .INC(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'd0),
        .CNTVALUEOUT(),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );

    IDELAYE2 #(
        .IDELAY_TYPE("FIXED")
    )
    phy_rxd_idelay_3
    (
        .IDATAIN(phy_rxd[3]),
        .DATAOUT(phy_rxd_delay[3]),
        .DATAIN(1'b0),
        .C(1'b0),
        .CE(1'b0),
        .INC(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'd0),
        .CNTVALUEOUT(),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );

    IDELAYE2 #(
        .IDELAY_VALUE(0),
        .IDELAY_TYPE("FIXED")
    )
    phy_rx_ctl_idelay
    (
        .IDATAIN(phy_rx_ctl),
        .DATAOUT(phy_rx_ctl_delay),
        .DATAIN(1'b0),
        .C(1'b0),
        .CE(1'b0),
        .INC(1'b0),
        .CINVCTRL(1'b0),
        .CNTVALUEIN(5'd0),
        .CNTVALUEOUT(),
        .LD(1'b0),
        .LDPIPEEN(1'b0),
        .REGRST(1'b0)
    );
end else begin : gen_generic_target
    logic unused;
    assign unused = clk_200_int;

    // For simulation we can ignore the input delay and just pass signals through
    assign phy_rx_ctl_delay = phy_rx_ctl;
    assign phy_rxd_delay = phy_rxd;
end
endgenerate

// Instantiate core
rgmii_core #(
    .TARGET(TARGET)
) core_inst (
    /*
     * Clock: 125MHz
     * Synchronous reset
     */
    .clk(clk_int),
    .clk90(clk90_int),
    .rst(rst_int),
    /*
     * Ethernet: 1000BASE-T RGMII
     */
    .phy_rx_clk      (phy_rx_clk),
    .phy_rxd         (phy_rxd_delay),
    .phy_rx_ctl      (phy_rx_ctl_delay),
    .phy_tx_clk      (phy_tx_clk),
    .phy_txd         (phy_txd),
    .phy_tx_ctl      (phy_tx_ctl),
    .phy_reset_n     (phy_reset_n),
    .mac_gmii_tx_en  (mac_gmii_tx_en),

    .tx_axis_tdata   (tx_axis_tdata),
    .tx_axis_tvalid  (tx_axis_tvalid),
    .tx_axis_tready  (tx_axis_tready),
    .tx_axis_tlast   (tx_axis_tlast),
    .tx_axis_tuser   (tx_axis_tuser),
    .rx_axis_tdata   (rx_axis_tdata),
    .rx_axis_tvalid  (rx_axis_tvalid),
    .rx_axis_tlast   (rx_axis_tlast),
    .rx_axis_tuser   (rx_axis_tuser),
    .rx_fcs_reg      (),
    .tx_fcs_reg      ()
);

    ////////////////
    // Assertions //
    ////////////////

    // Assert RGMII-ish outputs are known
    `ASSERT_KNOWN(PhyTxClkKnown_A,          phy_tx_clk,                         clk_int, rst_int)
    `ASSERT_KNOWN(PhyTxDKnown_A,            phy_txd,                            clk_int, rst_int)
    `ASSERT_KNOWN(PhyTxCtlKnown_A,          phy_tx_ctl,                         clk_int, rst_int)
    `ASSERT_KNOWN(PhyRstKnown_A,            phy_reset_n,                        clk_int, rst_int)
    `ASSERT_KNOWN(TxEnKnown_A,              mac_gmii_tx_en,                     clk_int, rst_int)

    // Assert TX AXI Stream is known
    `ASSERT_KNOWN(TxAxisTreadyKnown_A,      tx_axis_tready,                     clk_int, rst_int)

    // Assert RX AXI Stream is known
    `ASSERT_KNOWN(RxAxisTValidKnown_A,      rx_axis_tvalid,                     clk_int, rst_int)
    `ASSERT_KNOWN_IF(RxAxisTDataKnown_A,    rx_axis_tdata, rx_axis_tvalid,      clk_int, rst_int)
    `ASSERT_KNOWN_IF(RxAxisTLastKnown_A,    rx_axis_tlast, rx_axis_tvalid,      clk_int, rst_int)
    `ASSERT_KNOWN_IF(RxAxisTUserKnown_A,    rx_axis_tuser, rx_axis_tvalid,      clk_int, rst_int)

    // Assert some reset conditions
    // all other outputs are irrelevant on reset since their validity is subject to one of these signals
    `ASSERT(TxEnOnReset_A,          rst_int |-> !mac_gmii_tx_en,                    clk_int, 0)
    `ASSERT(TxCtlOnReset_A,         rst_int |=> !phy_tx_ctl,                        clk_int, 0) // `|=>` is used here because the ODDR introduces a one cycle latency which has no reset. It shouldn't matter since phy_reset_n will disable the whole PHY anyway
    `ASSERT(PHYResetOnReset_A,      rst_int |-> !phy_reset_n,                       clk_int, 0)
    `ASSERT(RxAxisInvalidOnReset_A, rst_int |-> !rx_axis_tvalid,                    clk_int, 0)
    //                                                                              ^ clock  ^ normally we would put a reset here to disable the assertion, but we want these ones to hold on reset

    // Assert packets are appropriately sized and spaced
    //`ifndef SYNTHESIS
    ethernet_rgmii_tx_assertions u_ethernet_rgmii_tx_assertions (
        .phy_tx_clk,
        .phy_tx_ctl,
        .phy_reset_n
    );
    //`endif
endmodule
