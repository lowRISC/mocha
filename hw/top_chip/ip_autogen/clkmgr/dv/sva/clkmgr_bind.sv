// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module clkmgr_bind;
`ifndef GATE_LEVEL
  bind clkmgr tlul_assert #(
    .EndpointType("Device")
  ) tlul_assert_device (.clk_i, .rst_ni, .h2d(tl_i), .d2h(tl_o));

  // In top-level testbench, do not bind the csr_assert_fpv to reduce simulation time.
`ifndef TOP_LEVEL_DV
  bind clkmgr clkmgr_csr_assert_fpv clkmgr_csr_assert (.clk_i, .rst_ni, .h2d(tl_i), .d2h(tl_o));
`endif

  bind clkmgr clkmgr_pwrmgr_sva_if #(.IS_USB(0)) clkmgr_pwrmgr_main_sva_if (
    .clk_i,
    .rst_ni,
    .clk_en(pwr_i.main_ip_clk_en),
    .status(pwr_o.main_status)
  );

  bind clkmgr clkmgr_pwrmgr_sva_if #(.IS_USB(0)) clkmgr_pwrmgr_io_sva_if (
    .clk_i,
    .rst_ni,
    .clk_en(pwr_i.io_ip_clk_en),
    .status(pwr_o.io_status)
  );

  bind clkmgr clkmgr_gated_clock_sva_if clkmgr_io_peri_sva_if (
    .clk(clocks_o.clk_io_powerup),
    .rst_n(rst_io_ni),
    .ip_clk_en(pwr_i.io_ip_clk_en),
    .sw_clk_en(clk_io_peri_sw_en),
    .scanmode(scanmode_i == prim_mubi_pkg::MuBi4True),
    .gated_clk(clocks_o.clk_io_peri)
  );

  // Assertions for transactional clocks.
  bind clkmgr clkmgr_trans_sva_if clkmgr_none_trans_sva_if (
    .clk(clk_main_i),
    .rst_n(rst_main_ni),
    .hint(reg2hw.clk_hints.clk_main_hint_hint.q),
    .idle(idle_i[HintMainHint] == prim_mubi_pkg::MuBi4True),
    .scanmode(scanmode_i == prim_mubi_pkg::MuBi4True),
    .status(hw2reg.clk_hints_status.clk_main_hint_val.d),
    .trans_clk(clocks_o.clk_main_hint)
  );


  // AON clock gating enables.
  bind clkmgr clkmgr_aon_cg_en_sva_if clkmgr_aon_cg_aon_powerup (
    .cg_en(cg_en_o.aon_powerup == prim_mubi_pkg::MuBi4True)
  );

  bind clkmgr clkmgr_aon_cg_en_sva_if clkmgr_aon_cg_io_powerup (
    .cg_en(cg_en_o.io_powerup == prim_mubi_pkg::MuBi4True)
  );

  bind clkmgr clkmgr_aon_cg_en_sva_if clkmgr_aon_cg_main_powerup (
    .cg_en(cg_en_o.main_powerup == prim_mubi_pkg::MuBi4True)
  );

  // Non-AON clock gating enables with no software control.
  bind clkmgr clkmgr_cg_en_sva_if clkmgr_cg_io_infra (
    .clk(clk_io),
    .rst_n(rst_io_ni),
    .ip_clk_en(clk_io_en),
    .sw_clk_en(1'b1),
    .scanmode(prim_mubi_pkg::MuBi4False),
    .cg_en(cg_en_o.io_infra == prim_mubi_pkg::MuBi4True)
  );

  bind clkmgr clkmgr_cg_en_sva_if clkmgr_cg_main_infra (
    .clk(clk_main),
    .rst_n(rst_main_ni),
    .ip_clk_en(clk_main_en),
    .sw_clk_en(1'b1),
    .scanmode(prim_mubi_pkg::MuBi4False),
    .cg_en(cg_en_o.main_infra == prim_mubi_pkg::MuBi4True)
  );

  // Software controlled gating enables.
  bind clkmgr clkmgr_cg_en_sva_if clkmgr_cg_io_peri (
    .clk(clk_io),
    .rst_n(rst_io_ni),
    .ip_clk_en(clk_io_en),
    .sw_clk_en(clk_io_peri_sw_en),
    .scanmode(prim_mubi_pkg::MuBi4False),
    .cg_en(cg_en_o.io_peri == prim_mubi_pkg::MuBi4True)
  );

  // Hint controlled gating enables.
  bind clkmgr clkmgr_cg_en_sva_if clkmgr_cg_main_hint (
    .clk(clk_main_i),
    .rst_n(rst_main_ni),
    .ip_clk_en(clk_main_en),
    .sw_clk_en(u_clk_main_hint_trans.sw_hint_synced || !u_clk_main_hint_trans.idle_valid),
    .scanmode(prim_mubi_pkg::MuBi4False),
    .cg_en(cg_en_o.main_hint == prim_mubi_pkg::MuBi4True)
  );

`endif
endmodule : clkmgr_bind
