// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/**
 * Covergroups that are dependent on run-time parameters that may be available
 * only in build_phase can be defined here
 * Covergroups may also be wrapped inside helper classes if needed.
 */

// Wrapper class for peripheral clock covergroup.
class clkmgr_peri_cg_wrap;
  // This covergroup collects signals affecting peripheral clock.
  covergroup peri_cg(string name) with function sample (bit enable, bit ip_clk_en, bit scanmode);
    option.name = name;
    option.per_instance = 1;

    csr_enable_cp: coverpoint enable;
    ip_clk_en_cp: coverpoint ip_clk_en;
    scanmode_cp: coverpoint scanmode;

    peri_cross: cross csr_enable_cp, ip_clk_en_cp, scanmode_cp{
      // The enable CSRs cannot be manipulated in low power mode.
      ignore_bins ignore_enable_off = peri_cross with (csr_enable_cp == 1 && ip_clk_en_cp == 0);
    }
  endgroup

  function new(string name);
    peri_cg = new(name);
  endfunction

  function void sample (bit enable, bit ip_clk_en, bit scanmode);
    peri_cg.sample(enable, ip_clk_en, scanmode);
  endfunction
endclass

// Wrapper class for transactional unit clock covergroup.
class clkmgr_trans_cg_wrap;
  // This covergroup collects signals affecting transactional clock.
  covergroup trans_cg(
      string name
  ) with function sample (
      bit hint, bit ip_clk_en, bit scanmode, bit idle
  );
    option.name = name;
    option.per_instance = 1;

    csr_hint_cp: coverpoint hint;
    ip_clk_en_cp: coverpoint ip_clk_en;
    scanmode_cp: coverpoint scanmode;
    idle_cp: coverpoint idle;

    trans_cross: cross csr_hint_cp, ip_clk_en_cp, scanmode_cp, idle_cp{
      // If the clock is disabled the unit must be idle.
      ignore_bins ignore_idle_off = trans_cross with (idle_cp == 0 && ip_clk_en_cp == 0);
      // The hint CSRs cannot be manipulated in low power mode.
      ignore_bins ignore_enable_off = trans_cross with (csr_hint_cp == 1 && ip_clk_en_cp == 0);
    }
  endgroup

  function new(string name);
    trans_cg = new(name);
  endfunction

  function void sample (bit hint, bit ip_clk_en, bit scanmode, bit idle);
    trans_cg.sample(hint, ip_clk_en, scanmode, idle);
  endfunction
endclass


class clkmgr_env_cov extends cip_base_env_cov #(
  .CFG_T(clkmgr_env_cfg)
);
  `uvm_component_utils(clkmgr_env_cov)

  // the base class provides the following handles for use:
  // clkmgr_env_cfg: cfg

  // These covergroups collect signals affecting peripheral clocks.
  clkmgr_peri_cg_wrap  peri_cg_wrap[NUM_PERI];

  // These covergroups collect signals affecting transactional clocks.
  clkmgr_trans_cg_wrap trans_cg_wrap[NUM_TRANS];


  // This collects coverage for recoverable errors.
  covergroup recov_err_cg with function sample (
      bit shadow_update
  );
    shadow_update_cp: coverpoint shadow_update;
  endgroup

  // This collects coverage for fatal errors.
  covergroup fatal_err_cg with function sample (
      bit shadow_storage, bit idle_cnt, bit reg_integ
  );
    reg_integ_cp: coverpoint reg_integ;
    idle_cnt_cp: coverpoint idle_cnt;
    shadow_storage_cp: coverpoint shadow_storage;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    // The peripheral Covergroups.
    foreach (peri_cg_wrap[i]) begin
      clkmgr_env_pkg::peri_e peri = clkmgr_env_pkg::peri_e'(i);
      peri_cg_wrap[i] = new(peri.name);
    end
    // The transactional covergroups.
    foreach (trans_cg_wrap[i]) begin
      clkmgr_env_pkg::trans_e trans = clkmgr_env_pkg::trans_e'(i);
      trans_cg_wrap[i] = new(trans.name);
    end
    recov_err_cg = new();
    fatal_err_cg = new();
  endfunction : new

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // [or instantiate covergroups here]
    // Please instantiate sticky_intr_cov array of objects for all interrupts that are sticky
    // See cip_base_env_cov for details
  endfunction

endclass
