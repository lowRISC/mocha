// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // vPlan tag_roundtrip: once Serving with the baseline configuration, write capabilities with
  // their tags set or clear to the covered region, as aligned bursts of one or more whole chunks,
  // then read each burst back in the same order
  class tagctrl_tag_roundtrip_seq_cfg extends tagctrl_seq_cfg;
    `uvm_object_utils(tagctrl_tag_roundtrip_seq_cfg)

    function new(string name = "tagctrl_tag_roundtrip_seq_cfg");
      super.new(name);
    endfunction

    constraint tag_roundtrip_c {
      configure == 1;
      baseline_cfg == 1;
      walk == WalkNone;
      cfg_weight == 0;
      tag_write_pct == 100;
      tag_readback == 1;
      num_ops == MaxOps / 2;
    }
  endclass

  class tagctrl_tag_roundtrip_test extends tagctrl_base_test;
    `uvm_component_utils(tagctrl_tag_roundtrip_test)

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      tagctrl_seq_cfg::type_id::set_type_override(tagctrl_tag_roundtrip_seq_cfg::get_type());
    endfunction

    function void configure_env(tagctrl_env_cfg env_cfg);
      env_cfg.min_set_tags_checked = 1;
    endfunction
  endclass
