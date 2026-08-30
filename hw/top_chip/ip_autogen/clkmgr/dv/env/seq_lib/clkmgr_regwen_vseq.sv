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


  task body();
    // Make sure the aon clock is running as slow as it is meant to, otherwise the aon clock
    // runs fast enough that we could end up triggering faults due to the random settings for
    // the thresholds.
    cfg.aon_clk_rst_vif.set_freq_khz(AonClkHz / 1_000);

    `uvm_info(`gfn, $sformatf("Will run %0d rounds", num_trans), UVM_MEDIUM)
    for (int i = 0; i < num_trans; ++i) begin
      check_jitter_regwen();
      apply_reset("HARD");
      // This is to make sure we don't start writes immediately after reset,
      // otherwise the tl_agent could mistakenly consider the following read
      // happens during reset.
      cfg.clk_rst_vif.wait_clks(4);
      csr_rd_check(.ptr(ral.measure_ctrl_regwen), .compare_value(1));
    end
  endtask : body

endclass : clkmgr_regwen_vseq
