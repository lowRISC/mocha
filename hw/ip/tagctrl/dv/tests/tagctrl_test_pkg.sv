// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// The tests of the tag controller. Each test only narrows the knobs of tagctrl_seq_cfg with a knob
// class of its own, and names the sequence it runs.

package tagctrl_test_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import tagctrl_env_pkg::*;
  import tagctrl_seq_pkg::*;

  `include "tagctrl_base_test.svh"
  `include "tagctrl_reset_state_test.svh"
  `include "tagctrl_register_map_test.svh"
  `include "tagctrl_region_registers_readback_test.svh"
  `include "tagctrl_control_start_test.svh"
  `include "tagctrl_tag_roundtrip_test.svh"
endpackage
