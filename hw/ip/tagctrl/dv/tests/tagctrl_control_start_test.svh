// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan control_start: while unlocked and Unconfigured, program the baseline configuration and
  // start. Status must leave Unconfigured for Zeroing, then reach Serving.
  class tagctrl_control_start_seq_cfg extends tagctrl_seq_cfg;
    `uvm_object_utils(tagctrl_control_start_seq_cfg)

    function new(string name = "tagctrl_control_start_seq_cfg");
      super.new(name);
    endfunction

    constraint control_start_c {
      configure == 1;
      baseline_cfg == 1;
      walk == WalkNone;
      tag_weight == 0;
      cfg_scope == CfgScopeStatus;
      cfg_write_pct == 0;
      num_ops inside {[1:4]};
    }
  endclass

  class tagctrl_control_start_test extends tagctrl_base_test;
    `uvm_component_utils(tagctrl_control_start_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tagctrl_seq_cfg::type_id::set_type_override(tagctrl_control_start_seq_cfg::get_type());
    endfunction

    function void configure_env(tagctrl_env_cfg env_cfg);
      env_cfg.check_zeroing_seen = 1'b1;
    endfunction
  endclass
