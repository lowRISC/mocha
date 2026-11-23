// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Step: poll status through the register model until Zeroing ends, then read tag_table_top as
  // software would to size the tag table
  class tagctrl_cfg_await_seq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_cfg_await_seq)

    localparam int unsigned MaxPolls = 10000;

    function new(string name = "tagctrl_cfg_await_seq");
      super.new(name);
    endfunction

    task body();
      tagctrl_reg_block ral = p_sequencer.cfg.ral;
      uvm_status_e      status;
      uvm_reg_data_t    data;
      for (int unsigned polls = 0; ; polls++) begin
        if (polls > MaxPolls) `uvm_fatal(get_full_name(), "Zeroing never ended")
        ral.status.read(status, data, .parent(this));
        if (!data[StatusZeroing]) break;
      end
      ral.tag_table_top.read(status, data, .parent(this));
    endtask
  endclass
