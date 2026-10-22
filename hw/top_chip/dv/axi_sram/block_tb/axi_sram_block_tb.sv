// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Block-level UVM testbench: the DUT is axi_sram alone, driven directly by an
// axi_vip_if (no chip, no crossbar). The axi_vip_if publishes the bus for the axi_sram env.

module axi_sram_block_tb;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import top_pkg::*;
  import axi_agent_pkg::*;
  import axi_sram_test_pkg::*;

  // axi_sram's word-address width for the 128 KiB / 64-bit-word geometry.
  localparam int unsigned SramAddrWidth =
      $clog2(axi_sram_test_pkg::SramSize / (top_pkg::AxiDataWidth / 8));

  wire clk;
  wire rst_n;
  clk_rst_if u_clk_rst (.clk(clk), .rst_n(rst_n));

  // DUT device-side AXI port, driven by the axi_vip_if.
  top_pkg::axi_dev_req_t  sram_req;
  top_pkg::axi_dev_resp_t sram_resp;

  axi_vip_if #(
    .req_t     (top_pkg::axi_dev_req_t),
    .resp_t    (top_pkg::axi_dev_resp_t),
    .IdWidth   (top_pkg::AxiDevIdWidth),
    .AddrWidth (top_pkg::AxiAddrWidth),
    .DataWidth (top_pkg::AxiDataWidth),
    .UserWidth (top_pkg::AxiUserWidth),
    .IfMode    (axi_agent_pkg::Manager)
  ) u_axi_vip (
    .clk_i     (clk),
    .rst_ni    (rst_n)
  );
  // Manager mode: drive the SRAM request from the VIP, observe its response.
  assign sram_req           = u_axi_vip.axi_req;
  assign u_axi_vip.axi_resp = sram_resp;

  // Functional coverage: a passive sampler on the same device port (see axi_sram_cov).
  axi_sram_cov u_cov (
    .clk_i     (clk      ),
    .rst_ni    (rst_n    ),
    .axi_req   (sram_req ),
    .axi_resp  (sram_resp)
  );

  // Assertions, reaching the DUT's internal tag signals by name.
  bind axi_sram axi_sram_assert u_axi_sram_assert (
    .clk_i,
    .rst_ni,
    .axi_req_i,
    .axi_resp_o,
    .sram_req,
    .sram_we_d,
    .sram_be,
    .sram_cheri_w_tag
  );

  axi_sram #(
    .AddrWidth(SramAddrWidth)
  ) dut (
    .clk_i     (clk),
    .rst_ni    (rst_n),
    .axi_req_i (sram_req),
    .axi_resp_o(sram_resp)
  );

  // Pre-clear the data + CHERI-tag memories at time 0: an X in the tag RMW read
  // trips prim_fifo_sync DataKnown_A.
  initial begin
    foreach (dut.u_ram.mem[i])     dut.u_ram.mem[i]     = '0;
    foreach (dut.u_tag_ram.mem[i]) dut.u_tag_ram.mem[i] = '0;
  end

  initial begin
    u_clk_rst.set_freq_mhz(100);
    u_clk_rst.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", u_clk_rst);
    run_test();
  end

endmodule
