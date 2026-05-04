/*
 *  Creation Date : December, 2025
 *  Description   : Wrapper for 1RW SRAM macros implementing a write atom enable
 */
module hpdcache_sram_watomenable
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned ATOM_SIZE = DATA_SIZE >= 8 ? 8 : DATA_SIZE
)
(
    input  logic                                         clk,
    input  logic                                         rst_n,
    input  logic                                         cs,
    input  logic                                         we,
    input  logic [ADDR_SIZE-1:0]                         addr,
    input  logic [DATA_SIZE-1:0]                         wdata,
    input  logic [(DATA_SIZE+ATOM_SIZE-1)/ATOM_SIZE-1:0] watomenable,
    output logic [DATA_SIZE-1:0]                         rdata
);

    hpdcache_sram_watomenable_1rw #(
        .ADDR_SIZE(ADDR_SIZE),
        .DATA_SIZE(DATA_SIZE),
        .DEPTH(DEPTH),
        .ATOM_SIZE(ATOM_SIZE)
    ) ram_i (
        .clk,
        .rst_n,
        .cs,
        .we,
        .addr,
        .wdata,
        .watomenable,
        .rdata
    );

endmodule : hpdcache_sram_watomenable
