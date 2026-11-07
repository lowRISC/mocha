/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the "License"); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File: $filename.v
 *
 * Description: Auto-generated bootrom
 */

// Auto-generated code
module debug_rom (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic         req_i,
  input  logic [63:0]  addr_i,
  output logic [63:0]  rdata_o
);

  localparam int unsigned RomSize = 42;

  logic [RomSize-1:0][63:0] mem;
  assign mem = {
    64'h00000000_7b200073,
    64'h7b302573_7b202473,
    64'h5600007b_10852823,
    64'hf1402473_5610007b,
    64'h9d5ff06f_7b302573,
    64'h7b202473_9e1ff06f,
    64'h5610007b_7b302573,
    64'h7b202473_00040a63,
    64'h5600007b_00447413,
    64'h40044403_00a40433,
    64'hf1402473_10052423,
    64'h00100073_5610007b,
    64'h7b302573_7b202473,
    64'h5600007b_10052c23,
    64'h5610007b_00100073,
    64'h7b302573_7b202473,
    64'h5600007b_10052c23,
    64'h5610007b_fd5ff06f,
    64'hf40416e3_00247413,
    64'h40044403_00a40433,
    64'hf1402473_04041863,
    64'h00147413_40044403,
    64'h00a40433_10852023,
    64'hf1402473_00c51513,
    64'h00c55513_00000517,
    64'h5610007b_7b351073,
    64'h7b241073_0ff0000f,
    64'h0200006f_12852023,
    64'h00c51513_00c55513,
    64'h00000517_5610007b,
    64'h7b351073_7b241073,
    64'h0ff0000f_0440006f,
    64'h12852423_00c51513,
    64'h00c55513_00000517,
    64'h5610007b_7b351073,
    64'h7b241073_0ff0000f,
    64'h00000013_02c0006f,
    64'h00000013_0100006f,
    64'h00000013_0c40006f,
    64'h00000013_0b40006f,
    64'h00000013_1280006f,
    64'h00000013_0780006f
  };

  logic [$clog2(RomSize)-1:0] addr_d, addr_q;

  assign addr_d = req_i ? addr_i[$clog2(RomSize)-1+3:3] : addr_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      addr_q <= '0;
    end else begin
      addr_q <= addr_d;
    end
  end

  // this prevents spurious Xes from propagating into
  // the speculative fetch stage of the core
  always_comb begin : p_outmux
    rdata_o = '0;
    if (addr_q < $clog2(RomSize+1)'(RomSize)) begin
      rdata_o = mem[addr_q];
    end
  end

endmodule
