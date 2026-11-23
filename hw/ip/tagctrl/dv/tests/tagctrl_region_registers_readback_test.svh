// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan region_registers_readback: write covered_base, covered_top and tag_table_base with any
  // 64-bit value and read each write back
  class tagctrl_region_registers_readback_seq_cfg extends tagctrl_seq_cfg;
    `uvm_object_utils(tagctrl_region_registers_readback_seq_cfg)

    function new(string name = "tagctrl_region_registers_readback_seq_cfg");
      super.new(name);
    endfunction

    constraint region_registers_readback_c {
      configure == 0;
      walk == WalkNone;
      tag_weight == 0;
      cfg_scope == CfgScopeRegion;
      cfg_write_pct == 100;
      region_any == 1;
      cfg_write_readback == 1;
      num_ops >= 6;
    }
  endclass

  class tagctrl_region_registers_readback_test extends tagctrl_base_test;
    `uvm_component_utils(tagctrl_region_registers_readback_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tagctrl_seq_cfg::type_id::set_type_override(
        tagctrl_region_registers_readback_seq_cfg::get_type());
    endfunction
  endclass
