// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan reset_state: out of reset, read every register, the performance registers and the
  // reserved space
  class tagctrl_reset_state_seq_cfg extends tagctrl_seq_cfg;
    `uvm_object_utils(tagctrl_reset_state_seq_cfg)

    function new(string name = "tagctrl_reset_state_seq_cfg");
      super.new(name);
    endfunction

    constraint reset_state_c {
      configure == 0;
      walk == WalkRead;
      tag_weight == 0;
      cfg_scope == CfgScopeAll;
      cfg_write_pct == 0;
      num_ops >= 20;
    }
  endclass

  class tagctrl_reset_state_test extends tagctrl_base_test;
    `uvm_component_utils(tagctrl_reset_state_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tagctrl_seq_cfg::type_id::set_type_override(tagctrl_reset_state_seq_cfg::get_type());
    endfunction
  endclass
