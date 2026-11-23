// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Step: write a command to control through the register model
  class tagctrl_cfg_command_seq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_cfg_command_seq)

    // Set before starting
    bit [63:0] command;

    function new(string name = "tagctrl_cfg_command_seq");
      super.new(name);
    endfunction

    task body();
      uvm_status_e status;
      p_sequencer.cfg.ral.control.write(status, command, .parent(this));
    endtask
  endclass
