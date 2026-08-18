// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
## measurement_live: measurement cannot run when ext_clk_bypass is false, because
## rtl/clkmgr.sv.tpl ties u_calib_rdy_sync .mubi_i to MuBi4False in that case.
## Full rationale in dv/clkmgr_sim_cfg.hjson.tpl.
<% measurement_live = ext_clk_bypass %>\

`include "clkmgr_base_vseq.sv"
`include "clkmgr_clk_status_vseq.sv"
`include "clkmgr_common_vseq.sv"
% if measurement_live:
`include "clkmgr_frequency_timeout_vseq.sv"
`include "clkmgr_frequency_vseq.sv"
% endif
% if ext_clk_bypass:
`include "clkmgr_extclk_vseq.sv"
% endif
`include "clkmgr_peri_vseq.sv"
`include "clkmgr_regwen_vseq.sv"
`include "clkmgr_smoke_vseq.sv"
`include "clkmgr_stress_all_vseq.sv"
`include "clkmgr_trans_vseq.sv"
