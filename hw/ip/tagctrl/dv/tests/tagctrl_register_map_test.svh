// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan register_map: while unlocked and Unconfigured, read, write and read again each register.
  // Control writes carry no command, and the region registers are written with a valid
  // configuration.
  class tagctrl_register_map_seq_cfg extends tagctrl_seq_cfg;
    `uvm_object_utils(tagctrl_register_map_seq_cfg)

    function new(string name = "tagctrl_register_map_seq_cfg");
      super.new(name);
    endfunction

    constraint register_map_c {
      configure == 0;
      baseline_cfg == 1;
      walk == WalkWriteRead;
      tag_weight == 0;
      cfg_scope == CfgScopeStatus;
      cfg_write_pct == 0;
      num_ops == 1;
    }
  endclass

  class tagctrl_register_map_test extends tagctrl_base_test;
    `uvm_component_utils(tagctrl_register_map_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tagctrl_seq_cfg::type_id::set_type_override(tagctrl_register_map_seq_cfg::get_type());
    endfunction
  endclass
