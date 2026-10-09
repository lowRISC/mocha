// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ram_upsizer_w8_r64
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Creates a RAM with an 8-bit write port and 64-bit read port.

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
ram_upsizer_w8_r64 #(
    .RD_ADDR_W  ()
) ram_upsizer_w8_r64_inst (
    .clk_i,
    .rst_ni,

    // Write interface
    .wr_en_i    (),
    .wr_addr_i  (),
    .wr_data_i  (),

    // Read interface
    .rd_en_i    (),
    .rd_addr_i  (),
    .rd_data_o  ()
);

*/

module ram_upsizer_w8_r64 #(
    parameter  RD_ADDR_W = 8,
    localparam WR_ADDR_W = RD_ADDR_W + 3,   // 8x more addresses for reads than writes (i.e. 64/8 = 8)
    localparam MEM_SIZE  = (1<<WR_ADDR_W) * 8 // in bits
    // TODO allow mem_size smaller than the address space and add an error bit to indicate out-of-bounds access
) (
    input clk_i,
    input rst_ni,

    // write port
    input                           wr_en_i, // write enable
    input           [WR_ADDR_W-1:0] wr_addr_i,
    input                     [7:0] wr_data_i,

    // read port
    input                           rd_en_i,
    input           [RD_ADDR_W-1:0] rd_addr_i,
    output logic             [63:0] rd_data_o
);

`ifdef SYNTHESIS
    xpm_memory_sdpram #(
        .MEMORY_SIZE              (MEM_SIZE),
        .ADDR_WIDTH_A             (WR_ADDR_W),
        .ADDR_WIDTH_B             (RD_ADDR_W),
        .WRITE_DATA_WIDTH_A       (8),
        .READ_DATA_WIDTH_B        (64),
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

    (* ram_style = "block" *) // hint for Vivado to infer block RAM
    logic [7:0] mem [(1<<WR_ADDR_W)-1:0];

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rd_data_o <= '0;
        end else if (rd_en_i) begin
            // Concatenate 8 bytes from the memory to form the 64-bit output
            rd_data_o <= {
                mem[rd_addr_i * 8 + 7],
                mem[rd_addr_i * 8 + 6],
                mem[rd_addr_i * 8 + 5],
                mem[rd_addr_i * 8 + 4],
                mem[rd_addr_i * 8 + 3],
                mem[rd_addr_i * 8 + 2],
                mem[rd_addr_i * 8 + 1],
                mem[rd_addr_i * 8 + 0]
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
