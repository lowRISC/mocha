// Copyright lowRISC contributors (OpenTitan project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The regwen vseq attempts to write to registers whose regwen is randomly on or off to check
// the register contents is not updated when off. More details in the clkmgr_testplan.hjson file.
class clkmgr_regwen_vseq extends clkmgr_base_vseq;
  `uvm_object_utils(clkmgr_regwen_vseq)

  `uvm_object_new

  task check_jitter_regwen();
    bit enable;
    logic [3:0] prev_value_bits;
    mubi4_t     new_value;

    `DV_CHECK_STD_RANDOMIZE_FATAL(enable)
    new_value = get_rand_mubi4_val(.t_weight(1), .f_weight(1), .other_weight(2));
    `uvm_info(`gfn, $sformatf("Check jitter_regwen = %b", enable), UVM_MEDIUM)
    csr_wr(.ptr(ral.jitter_regwen), .value(enable));
    csr_rd(.ptr(ral.jitter_enable), .value(prev_value_bits));
    csr_wr(.ptr(ral.jitter_enable), .value(new_value));
    csr_rd_check(.ptr(ral.jitter_enable), .compare_value(enable ? new_value : prev_value_bits));
    `uvm_info(`gfn, "Check jitter_regwen done", UVM_MEDIUM)
  endtask : check_jitter_regwen

  // calib_rdy is tied to MuBi4False, so hardware holds measure_ctrl_regwen at 1 and forces any
  // measurement enable back to MuBi4False. Check software cannot defeat either.
  task check_meas_ctrl_disabled();
    csr_wr(.ptr(ral.measure_ctrl_regwen), .value(0));
    foreach (ExpectedCounts[clk]) begin
      clk_mesr_e clk_mesr = clk_mesr_e'(clk);
      csr_wr(.ptr(meas_ctrl_regs[clk_mesr].en), .value(MuBi4True));
      void'(meas_ctrl_regs[clk_mesr].en.predict(MuBi4False));
    end
    // Clearing the enables crosses clock domains; clkmgr_lost_calib_ctrl_en_sva_if allows up
    // to 45 cycles for it.
    cfg.clk_rst_vif.wait_clks(50);
    calibration_lost_checks();
  endtask : check_meas_ctrl_disabled

  task body();

    `uvm_info(`gfn, $sformatf("Will run %0d rounds", num_trans), UVM_MEDIUM)
    for (int i = 0; i < num_trans; ++i) begin
      check_jitter_regwen();
      check_meas_ctrl_disabled();
      apply_reset("HARD");
      // This is to make sure we don't start writes immediately after reset,
      // otherwise the tl_agent could mistakenly consider the following read
      // happens during reset.
      cfg.clk_rst_vif.wait_clks(4);
      csr_rd_check(.ptr(ral.measure_ctrl_regwen), .compare_value(1));
    end
  endtask : body

endclass : clkmgr_regwen_vseq
