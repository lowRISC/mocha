// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Block-level testbench for the tag controller. An axi_vip_if drives each of the configuration
// and tagged subordinates, and a simulation memory answers the untagged manager.

module tb;
  import uvm_pkg::*;
  import axi_agent_pkg::*;
  import tagctrl_env_pkg::*;
  import tagctrl_test_pkg::*;
  `include "uvm_macros.svh"
  `include "axi/typedef.svh"

  typedef logic [AxiIdWidth-1:0]     slv_id_t;
  typedef logic [AxiIdWidth:0]       mst_id_t;
  typedef logic [AxiAddrWidth-1:0]   addr_t;
  typedef logic [AxiDataWidth-1:0]   data_t;
  typedef logic [AxiDataWidth/8-1:0] strb_t;
  typedef logic [AxiUserWidth-1:0]   user_t;
  `AXI_TYPEDEF_ALL(slv, addr_t, slv_id_t, data_t, strb_t, user_t)
  `AXI_TYPEDEF_ALL(mst, addr_t, mst_id_t, data_t, strb_t, user_t)

  wire clk;
  wire rst_n;
  clk_rst_if u_clk_rst (.clk(clk), .rst_n(rst_n));

  slv_req_t  cfg_req, tag_req;
  slv_resp_t cfg_resp, tag_resp;
  mst_req_t  mem_req;
  mst_resp_t mem_resp, mem_resp_raw;

  axi_vip_if #(
    .req_t     (slv_req_t),
    .resp_t    (slv_resp_t),
    .IdWidth   (AxiIdWidth),
    .AddrWidth (AxiAddrWidth),
    .DataWidth (AxiDataWidth),
    .UserWidth (AxiUserWidth),
    .IfMode    (Manager),
    .CfgScope  ("*.env.m_cfg_agent")
  ) u_cfg_vip (
    .clk_i  (clk),
    .rst_ni (rst_n)
  );
  assign cfg_req           = u_cfg_vip.axi_req;
  assign u_cfg_vip.axi_resp = cfg_resp;

  axi_vip_if #(
    .req_t     (slv_req_t),
    .resp_t    (slv_resp_t),
    .IdWidth   (AxiIdWidth),
    .AddrWidth (AxiAddrWidth),
    .DataWidth (AxiDataWidth),
    .UserWidth (AxiUserWidth),
    .IfMode    (Manager),
    .CfgScope  ("*.env.m_tag_agent")
  ) u_tag_vip (
    .clk_i  (clk),
    .rst_ni (rst_n)
  );
  assign tag_req           = u_tag_vip.axi_req;
  assign u_tag_vip.axi_resp = tag_resp;

  axi_tagctrl_top #(
    .init_start              (1'b0),
    .init_locked             (1'b0),
    .allow_resume            (1'b0),
    .allow_flush_when_locked (1'b0),
    .perf_counters           (PerfCounters),
    .axi_id_width            (AxiIdWidth),
    .axi_addr_width          (AxiAddrWidth),
    .axi_data_width          (AxiDataWidth),
    .axi_user_width          (AxiUserWidth),
    .slv_req_t               (slv_req_t),
    .slv_resp_t              (slv_resp_t),
    .mst_req_t               (mst_req_t),
    .mst_resp_t              (mst_resp_t)
  ) dut (
    .clk_i               (clk),
    .rst_ni              (rst_n),
    .test_i              (1'b0),
    .config_sub_req_i    (cfg_req),
    .config_sub_resp_o   (cfg_resp),
    .tagged_sub_req_i    (tag_req),
    .tagged_sub_resp_o   (tag_resp),
    .untagged_mgr_req_o  (mem_req),
    .untagged_mgr_resp_i (mem_resp)
  );

  // The memory leaves the byte lanes a read beat does not use at X. AXI lets them hold any value,
  // and the DUT FIFOs check that what they store is known, so those lanes read 0.
  always_comb begin
    mem_resp = mem_resp_raw;
    foreach (mem_resp.r.data[i]) mem_resp.r.data[i] = mem_resp_raw.r.data[i] === 1'b1;
  end

  // Memory contents are undefined until written
  axi_sim_mem #(
    .AddrWidth         (AxiAddrWidth),
    .DataWidth         (AxiDataWidth),
    .IdWidth           (AxiIdWidth + 1),
    .UserWidth         (AxiUserWidth),
    .axi_req_t         (mst_req_t),
    .axi_rsp_t         (mst_resp_t),
    .UninitializedData ("random"),
    .ApplDelay         (1ns),
    .AcqDelay          (9ns)
  ) u_mem (
    .clk_i              (clk),
    .rst_ni             (rst_n),
    .axi_req_i          (mem_req),
    .axi_rsp_o          (mem_resp_raw),
    .mon_w_valid_o      (),
    .mon_w_addr_o       (),
    .mon_w_data_o       (),
    .mon_w_id_o         (),
    .mon_w_user_o       (),
    .mon_w_beat_count_o (),
    .mon_w_last_o       (),
    .mon_r_valid_o      (),
    .mon_r_addr_o       (),
    .mon_r_data_o       (),
    .mon_r_id_o         (),
    .mon_r_user_o       (),
    .mon_r_beat_count_o (),
    .mon_r_last_o       ()
  );

  initial begin
    u_clk_rst.drive_rst_pin(1'b0);
    u_clk_rst.set_freq_mhz(100);
    u_clk_rst.set_active();
    uvm_config_db#(virtual clk_rst_if)::set(null, "*", "clk_rst_vif", u_clk_rst);
    run_test();
  end
endmodule
