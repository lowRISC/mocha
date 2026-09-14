// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ram_downsizer_w64_r8
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Creates a RAM with an 8-bit read port and 64-bit write port.

If SYNTHESIS is defined by the preprocessor, then a Xilinx XPM is instantiated.
Otherwise, a simple packed logic is instantiated to model the memory.

Read latency of 1 cycle (i.e. data is output on the next clock after the address
is provided).

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
There are no dedicated tests for this module.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
ram_downsizer_w64_r8 #(
    .WR_ADDR_W  ()
) ram_downsizer_w64_r8_inst (
    .clk_i,
    .rst_ni,

    // Writes interface
    .wr_en_i    (),
    .wr_addr_i  (),
    .wr_data_i  (),

    // Read interface
    .rd_en_i    (),
    .rd_addr_i  (),
    .rd_data_o  ()
);

*/

module ram_downsizer_w64_r8 #(
    parameter  WR_ADDR_W = 8,
    localparam RD_ADDR_W = WR_ADDR_W + 3,   // 8x more addresses for reads than writes (i.e. 64/8 = 8)
    localparam MEM_SIZE  = (1<<WR_ADDR_W) * 64 // in bits
    // TODO allow mem_size smaller than the address space and add an error bit to indicate out-of-bounds access
) (
    input clk_i,
    input rst_ni,

    // write port
    input                           wr_en_i, // write enable
    input           [WR_ADDR_W-1:0] wr_addr_i,
    input                    [63:0] wr_data_i,

    // read port
    input                           rd_en_i,
    input           [RD_ADDR_W-1:0] rd_addr_i,
    output logic              [7:0] rd_data_o
);

`ifdef SYNTHESIS
    xpm_memory_sdpram #(
        .MEMORY_SIZE              (MEM_SIZE),
        .ADDR_WIDTH_A             (WR_ADDR_W),
        .ADDR_WIDTH_B             (RD_ADDR_W),
        .WRITE_DATA_WIDTH_A       (64),
        .READ_DATA_WIDTH_B        (8),
        .BYTE_WRITE_WIDTH_A       (8),

        .USE_MEM_INIT             (0),
        .READ_LATENCY_B           (1)
    ) xpm_memory_sdpram_inst (
        // Port A (write)
        .clka            (clk_i),
        .ena             (wr_en_i),
        .wea             ('1),
        .addra           (wr_addr_i),
        .dina            (wr_data_i),

        // Port B (read)
        .clkb            (clk_i),
        .rstb            (~rst_ni),
        .enb             (rd_en_i),
        .addrb           (rd_addr_i),
        .doutb           (rd_data_o),

        // Power saving options (not used here)
        .regceb          (1'b1), // clock enable
        .sleep           (1'b0),

        // ECC options (not used here)
        .injectsbiterra  (1'b0),    // inject single bit error
        .injectdbiterra  (1'b0),    // inject double bit error
        .sbiterrb        (),        // single bit error detected
        .dbiterrb        ()         // douible bit error detected
    );
`else
    logic unused;
    assign unused = ^MEM_SIZE;

    logic [63:0] mem [(1<<WR_ADDR_W)-1:0];

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rd_data_o <= '0;
        end else if (rd_en_i) begin
            rd_data_o <= {
                mem[rd_addr_i[RD_ADDR_W-1:3]][rd_addr_i[2:0] * 8 +: 8] // convert from byte address to word address and index the byte offset
            };
        end
    end

    always_ff @ (posedge clk_i) begin
        if (wr_en_i) begin
            mem[wr_addr_i] <= wr_data_i;
        end
    end
`endif
endmodule
