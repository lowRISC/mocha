/*
 *  Creation Date : December, 2025
 *  Description   : Behavioral model of a 1RW SRAM with write atom enable
 */
module hpdcache_sram_watomenable_1rw
#(
    parameter int unsigned ADDR_SIZE = 0,
    parameter int unsigned DATA_SIZE = 0,
    parameter int unsigned DEPTH = 2**ADDR_SIZE,
    parameter int unsigned ATOM_SIZE = DATA_SIZE >= 8 ? 8 : DATA_SIZE
)
(
    input  logic                         clk,
    input  logic                         rst_n,
    input  logic                         cs,
    input  logic                         we,
    input  logic [ADDR_SIZE-1:0]         addr,
    input  logic [DATA_SIZE-1:0]         wdata,
    input  logic [(DATA_SIZE+ATOM_SIZE-1)/ATOM_SIZE-1:0] watomenable,
    output logic [DATA_SIZE-1:0]         rdata
);

    /*
     *  Internal memory array declaration
     */
    typedef logic [DATA_SIZE-1:0] mem_t [DEPTH];
    mem_t mem;
    logic [ADDR_SIZE-1:0] addr_reg;

    assign rdata = mem[addr_reg];


    /*
     *  Process to update or read the memory array
     */
    always_ff @(posedge clk)
    begin : mem_update_ff
        if (cs == 1'b1) begin
            if (we == 1'b1) begin
                for (int i = 0; i < (DATA_SIZE+ATOM_SIZE-1)/ATOM_SIZE; i++) begin
                    if (watomenable[i])
                      mem[addr][i*ATOM_SIZE +: ATOM_SIZE] <= wdata[i*ATOM_SIZE +: ATOM_SIZE];
                end
            end
            addr_reg <= addr;
        end
        //rdata <= mem[addr];
    end : mem_update_ff
endmodule : hpdcache_sram_watomenable_1rw
