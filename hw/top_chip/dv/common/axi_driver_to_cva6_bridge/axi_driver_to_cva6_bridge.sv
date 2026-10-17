// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Stand-in for the CVA6 core: an active axi_vip_if drives the CVA6 crossbar host port, so UVM
// sequences issue AXI traffic where the CPU would. Swapped in by tb_cfg when
// SWAP_CVA6_WITH_AXI_DRIVER is defined.
//
// The parameter and port list mirrors the cva6 instance in top_chip_system, as the config can only
// substitute a module that accepts the same overrides and connections. Everything apart from the
// clock, reset and AXI port is ignored.

module axi_driver_to_cva6_bridge #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = '0,
  parameter type axi_ar_chan_t = logic,
  parameter type axi_aw_chan_t = logic,
  parameter type axi_w_chan_t  = logic,
  parameter type b_chan_t      = logic,
  parameter type r_chan_t      = logic,
  parameter type noc_req_t     = top_pkg::axi_req_t,
  parameter type noc_resp_t    = top_pkg::axi_resp_t
) (
  input  logic                     clk_i,
  input  logic                     rst_ni,
  input  logic [CVA6Cfg.PCLEN-1:0] boot_addr_i,
  input  logic [CVA6Cfg.XLEN-1:0]  hart_id_i,
  input  logic [1:0]               irq_i,
  input  logic                     ipi_i,
  input  logic                     time_irq_i,
  input  logic                     debug_req_i,
  output logic                     rvfi_probes_o,
  output logic                     cvxif_req_o,
  input  logic                     cvxif_resp_i,
  output noc_req_t                 noc_req_o,
  input  noc_resp_t                noc_resp_i
);
  assign rvfi_probes_o = 1'b0;
  assign cvxif_req_o   = 1'b0;

  axi_vip_if #(
    .req_t     (noc_req_t             ),
    .resp_t    (noc_resp_t            ),
    .IdWidth   (top_pkg::AxiIdWidth   ),
    .AddrWidth (top_pkg::AxiAddrWidth ),
    .DataWidth (top_pkg::AxiDataWidth ),
    .UserWidth (top_pkg::AxiUserWidth ),
    .IsActive  (uvm_pkg::UVM_ACTIVE   ),
    .InstId    ("CVA6_BRIDGE"         ),
    .CfgScope  ("*.m_cva6_axi_agent"  )
  ) u_axi_vip (
    .clk_i  (clk_i ),
    .rst_ni (rst_ni)
  );

  assign noc_req_o          = u_axi_vip.axi_req;
  assign u_axi_vip.axi_resp = noc_resp_i;
endmodule : axi_driver_to_cva6_bridge
