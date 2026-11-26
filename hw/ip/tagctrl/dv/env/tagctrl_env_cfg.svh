// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Set up by the test before the env is built
  class tagctrl_env_cfg extends uvm_object;
    `uvm_object_utils(tagctrl_env_cfg)

    // Report mismatches. The predictor runs either way.
    bit en_scb = 1'b1;

    // Fail a test that starts the controller and never reads Zeroing from status
    bit check_zeroing_seen;

    // Fail a test that checks fewer set tags than this
    int unsigned min_set_tags_checked;

    // The testbench clock and reset generator
    virtual clk_rst_if clk_rst_vif;

    tagctrl_reg_block ral;

    function new(string name = "");
      super.new(name);
    endfunction

    // Build and lock the register model at offset 0 of the configuration subordinate
    function void initialize();
      ral = tagctrl_reg_block::type_id::create("ral");
      ral.build(0);
      ral.lock_model();
    endfunction
  endclass
