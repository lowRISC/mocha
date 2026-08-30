/*

Copyright (c) 2015-2018 Alex Forencich

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

*/

// Language: Verilog 2001

/*
 * 1G Ethernet MAC with RGMII interface and RX FIFO
 */
module eth_mac_1g_rgmii_wrapper #
(
    // target (e.g. Xilinx FPGA, generic model, etc.)
    parameter TARGET = "SIM", // "SIM", "GENERIC", "XILINX", or "ALTERA"
    // IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6
    parameter IODDR_STYLE = "IODDR2",
    // Clock input style ("BUFG", "BUFR", "BUFIO", "BUFIO2")
    // Use BUFR for Virtex-5, Virtex-6, 7-series
    // Use BUFG for Ultrascale
    // Use BUFIO2 for Spartan-6
    parameter CLOCK_INPUT_STYLE = "BUFIO2",
    // Use 90 degree clock for RGMII transmit ("TRUE", "FALSE")
    parameter USE_CLK90 = "TRUE",
    parameter ENABLE_PADDING = 1,
    parameter MIN_FRAME_LENGTH = 64
)
(
    input wire         gtx_clk,
    input wire         gtx_clk90,
    input wire         gtx_rst,
    input wire         logic_clk,
    input wire         logic_rst,

    /*
     * AXI input
     */
    input wire [7:0]   tx_axis_tdata,
    input wire         tx_axis_tvalid,
    output wire        tx_axis_tready,
    input wire         tx_axis_tlast,
    input wire         tx_axis_tuser,

    /*
     * AXI output
     */
    output wire [7:0]  rx_axis_tdata,
    output wire        rx_axis_tvalid,
    output wire        rx_axis_tlast,
    output wire        rx_axis_tuser,

    /*
     * RGMII interface
     */
    input wire         rgmii_rx_clk,
    input wire [3:0]   rgmii_rxd,
    input wire         rgmii_rx_ctl,
    output wire        rgmii_tx_clk,
    output wire [3:0]  rgmii_txd,
    output wire        rgmii_tx_ctl,
    output wire        mac_gmii_tx_en,

    /*
     * Status
     */
    output wire        rx_error_bad_frame,
    output wire        rx_error_bad_fcs,
    output wire [1:0]  speed,
    output wire [31:0] rx_fcs_reg,
    output wire [31:0] tx_fcs_reg,

    /*
     * Configuration
     */
    input wire [7:0]   ifg_delay
);

wire rx_clk;
wire rx_rst;

// RX AXI Stream signals between FIFO and MAC
wire       rx_fifo_axis_tvalid;
wire [7:0] rx_fifo_axis_tdata;
wire       rx_fifo_axis_tlast;
wire       rx_fifo_axis_tuser;

// synchronize MAC status signals into logic clock domain
wire rx_error_bad_frame_int;
wire rx_error_bad_fcs_int;

reg [1:0] rx_sync_reg_1;
reg [1:0] rx_sync_reg_2;
reg [1:0] rx_sync_reg_3;
reg [1:0] rx_sync_reg_4;

assign rx_error_bad_frame = rx_sync_reg_3[0] ^ rx_sync_reg_4[0];
assign rx_error_bad_fcs = rx_sync_reg_3[1] ^ rx_sync_reg_4[1];

always @(posedge rx_clk or posedge rx_rst) begin
    if (rx_rst) begin
        rx_sync_reg_1 <= 2'd0;
    end else begin
        rx_sync_reg_1 <= rx_sync_reg_1 ^ {rx_error_bad_fcs_int, rx_error_bad_frame_int};
    end
end

always @(posedge logic_clk or posedge logic_rst) begin
    if (logic_rst) begin
        rx_sync_reg_2 <= 2'd0;
        rx_sync_reg_3 <= 2'd0;
        rx_sync_reg_4 <= 2'd0;
    end else begin
        rx_sync_reg_2 <= rx_sync_reg_1;
        rx_sync_reg_3 <= rx_sync_reg_2;
        rx_sync_reg_4 <= rx_sync_reg_3;
    end
end


wire [1:0] speed_int;

reg [1:0] speed_sync_reg_1;
reg [1:0] speed_sync_reg_2;

assign speed = speed_sync_reg_2;

always @(posedge logic_clk) begin
    speed_sync_reg_1 <= speed_int;
    speed_sync_reg_2 <= speed_sync_reg_1;
end

eth_mac_1g_rgmii #(
    .TARGET             (TARGET),
    .IODDR_STYLE        (IODDR_STYLE),
    .CLOCK_INPUT_STYLE  (CLOCK_INPUT_STYLE),
    .USE_CLK90          (USE_CLK90),
    .ENABLE_PADDING     (ENABLE_PADDING),
    .MIN_FRAME_LENGTH   (MIN_FRAME_LENGTH)
)
eth_mac_1g_rgmii_inst (
    .gtx_clk        (gtx_clk            ),
    .gtx_clk90      (gtx_clk90          ),
    .gtx_rst        (gtx_rst            ),

    // TX AXI Stream
    .tx_clk         (                   ),  // TX clk is identical to logic rst for now, so we don't need CDC
                                            // TODO this is true in our current setup but not true in general as this module has separate inputs for logic_clk and gtx_clk
    .tx_rst         (                   ),
    .tx_axis_tdata  (tx_axis_tdata      ),
    .tx_axis_tvalid (tx_axis_tvalid     ),
    .tx_axis_tready (tx_axis_tready     ),
    .tx_axis_tlast  (tx_axis_tlast      ),
    .tx_axis_tuser  (tx_axis_tuser      ),

    // RX AXI Stream
    .rx_clk         (rx_clk             ),
    .rx_rst         (rx_rst             ),
    .rx_axis_tdata  (rx_fifo_axis_tdata ),
    .rx_axis_tvalid (rx_fifo_axis_tvalid),
    .rx_axis_tlast  (rx_fifo_axis_tlast ),
    .rx_axis_tuser  (rx_fifo_axis_tuser ),

    // RGMII RX
    .rgmii_rx_clk   (rgmii_rx_clk       ),
    .rgmii_rxd      (rgmii_rxd          ),
    .rgmii_rx_ctl   (rgmii_rx_ctl       ),

    // RGMII TX
    .rgmii_tx_clk   (rgmii_tx_clk       ),
    .rgmii_txd      (rgmii_txd          ),
    .rgmii_tx_ctl   (rgmii_tx_ctl       ),

    // Status
    .mac_gmii_tx_en(mac_gmii_tx_en),
    .rx_error_bad_frame(rx_error_bad_frame_int),
    .rx_error_bad_fcs(rx_error_bad_fcs_int),
    .rx_fcs_reg(rx_fcs_reg),
    .tx_fcs_reg(tx_fcs_reg),
    .speed(speed_int),

    // Config
    .ifg_delay(ifg_delay)
);

// I have chosen a depth of 8 for RX FIFO
// The RGMII clocks are strictly less than or equal to the AXI clock (125 MHz)
// and backpressure on the AXI side is completely fine, so buffering isn't needed
// we only really need the FIFOs to provide CDC
// assuming the CDC propagates in 2-3 cycles of the destination clock, a depth of 4 would be enough
// but if the reset synchronisers happens to reach the source domain one cycle sooner we could have a little bit of overflow
// so a depth of 8 is a safe choice
// FIFO width is the width of the AXI Stream (8 data bits + 1 user bit + 1 valid bit + 1 last bit = 11 bits) so this is pretty cheap
localparam RX_FIFO_DEPTH = 8;

// FIFO for the RX path to cross from MAC clock domain to logic clock domain
prim_fifo_async #(
    .Width(8+1+1), // data + last + user
    .Depth(RX_FIFO_DEPTH),
    .OutputZeroIfEmpty(1'b1) // drive zeros when the FIFO is empty to avoid any metastable data being sent to the logic domain
) rx_fifo (
    .clk_wr_i      (rx_clk              ),
    .rst_wr_ni     (!rx_rst             ),
    .clk_rd_i      (logic_clk           ),
    .rst_rd_ni     (!logic_rst          ),
    .wvalid_i      (rx_fifo_axis_tvalid ),
    .wready_o      (                    ), // no backpressure should ever be put on the RX stream
    .wdata_i       ({rx_fifo_axis_tdata,
                     rx_fifo_axis_tlast,
                     rx_fifo_axis_tuser}),
    .rvalid_o      (rx_axis_tvalid      ),
    .rready_i      (1'b1                ), // no backpressure should ever be put on the RX stream
    .rdata_o       ({rx_axis_tdata,
                     rx_axis_tlast,
                     rx_axis_tuser     }),
    .wdepth_o      (                    ), // not used
    .rdepth_o      (                    )  // not used
);

endmodule
