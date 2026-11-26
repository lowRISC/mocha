// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Step: write covered_base, covered_top and tag_table_base through the register model
  class tagctrl_cfg_program_seq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_cfg_program_seq)

    // Set before starting
    bit [63:0] covered_base;
    bit [63:0] covered_top;
    bit [63:0] tag_table_base;

    function new(string name = "tagctrl_cfg_program_seq");
      super.new(name);
    endfunction

    task body();
      tagctrl_reg_block ral = p_sequencer.cfg.ral;
      uvm_status_e      status;
      ral.covered_base.write(status, covered_base, .parent(this));
      ral.covered_top.write(status, covered_top, .parent(this));
      ral.tag_table_base.write(status, tag_table_base, .parent(this));
    endtask
  endclass
