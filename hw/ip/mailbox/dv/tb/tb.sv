// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Mailbox testbench with the top_chip_system configuration and one AXI manager agent per port
module tb;
  import uvm_pkg::*;
  import mailbox_env_pkg::*;
  import mailbox_test_pkg::*;

  `include "uvm_macros.svh"

  wire                clk;
  wire                rst_n;
  wire [NumPorts-1:0] irq;

  top_pkg::axi_lite_req_t  [NumPorts-1:0] dut_reqs;
  top_pkg::axi_lite_resp_t [NumPorts-1:0] dut_resps;

  clk_rst_if clk_rst_if (.clk(clk), .rst_n(rst_n));
  pins_if #(NumPorts) intr_if (.pins(irq));

  axi_lite_mailbox #(
    .MailboxDepth (MailboxDepth            ),
    .AxiAddrWidth (top_pkg::AxiAddrWidth   ),
    .AxiDataWidth (top_pkg::AxiDataWidth   ),
    .req_lite_t   (top_pkg::axi_lite_req_t ),
    .resp_lite_t  (top_pkg::axi_lite_resp_t),
    .addr_t       (top_pkg::addr_t         )
  ) dut (
    .clk_i       (clk                                                ),
    .rst_ni      (rst_n                                              ),
    .test_i      (1'b0                                               ),
    .slv_reqs_i  (dut_reqs                                           ),
    .slv_resps_o (dut_resps                                          ),
    .irq_o       (irq                                                ),
    .base_addr_i ({top_pkg::MailboxExtBaseAddr, top_pkg::MailboxBase})
  );

  for (genvar i = 0; i < NumPorts; i++) begin : gen_port
    axi_vip_if #(
      .req_t     (top_pkg::axi_req_t                 ),
      .resp_t    (top_pkg::axi_resp_t                ),
      .IdWidth   (top_pkg::AxiIdWidth                ),
      .AddrWidth (top_pkg::AxiAddrWidth              ),
      .DataWidth (top_pkg::AxiDataWidth              ),
      .UserWidth (top_pkg::AxiUserWidth              ),
      .IsLite    (1'b1                               ),
      .IfMode    (axi_agent_pkg::Manager             ),
      .CfgScope  ({"*.env.m_axi_agent_", PortName[i]})
    ) u_axi_vip_if (
      .clk_i  (clk  ),
      .rst_ni (rst_n)
    );

    // Connect the AXI4-Lite subset of the full AXI request
    assign dut_reqs[i].aw.addr  = u_axi_vip_if.axi_req.aw.addr;
    assign dut_reqs[i].aw.prot  = u_axi_vip_if.axi_req.aw.prot;
    assign dut_reqs[i].aw_valid = u_axi_vip_if.axi_req.aw_valid;
    assign dut_reqs[i].w.data   = u_axi_vip_if.axi_req.w.data;
    assign dut_reqs[i].w.strb   = u_axi_vip_if.axi_req.w.strb;
    assign dut_reqs[i].w_valid  = u_axi_vip_if.axi_req.w_valid;
    assign dut_reqs[i].b_ready  = u_axi_vip_if.axi_req.b_ready;
    assign dut_reqs[i].ar.addr  = u_axi_vip_if.axi_req.ar.addr;
    assign dut_reqs[i].ar.prot  = u_axi_vip_if.axi_req.ar.prot;
    assign dut_reqs[i].ar_valid = u_axi_vip_if.axi_req.ar_valid;
    assign dut_reqs[i].r_ready  = u_axi_vip_if.axi_req.r_ready;

    // Tie unused ID, USER and RLAST fields to legal full-AXI values
    assign u_axi_vip_if.axi_resp.aw_ready = dut_resps[i].aw_ready;
    assign u_axi_vip_if.axi_resp.w_ready  = dut_resps[i].w_ready;
    assign u_axi_vip_if.axi_resp.b.id     = '0;
    assign u_axi_vip_if.axi_resp.b.resp   = dut_resps[i].b.resp;
    assign u_axi_vip_if.axi_resp.b.user   = '0;
    assign u_axi_vip_if.axi_resp.b_valid  = dut_resps[i].b_valid;
    assign u_axi_vip_if.axi_resp.ar_ready = dut_resps[i].ar_ready;
    assign u_axi_vip_if.axi_resp.r.id     = '0;
    assign u_axi_vip_if.axi_resp.r.data   = dut_resps[i].r.data;
    assign u_axi_vip_if.axi_resp.r.resp   = dut_resps[i].r.resp;
    assign u_axi_vip_if.axi_resp.r.last   = 1'b1;
    assign u_axi_vip_if.axi_resp.r.user   = '0;
    assign u_axi_vip_if.axi_resp.r_valid  = dut_resps[i].r_valid;
  end : gen_port

  initial begin
    clk_rst_if.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", clk_rst_if);
    uvm_config_db#(virtual pins_if #(NumPorts))::set(null, "*", "intr_vif", intr_if);
    run_test();
  end
endmodule : tb
