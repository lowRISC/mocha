// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// The stimulus for the tag controller, in layers. It uses tagctrl_env_pkg and never the other way
// round.
//
//   tagctrl_seq_cfg.svh          -- the knobs, randomised once per seed
//   tagctrl_op.svh               -- one access, and the random access the knobs shape
//   tagctrl_base_seq.svh         -- runs on the virtual sequencer, helpers for the steps
//   tagctrl_*_seq.svh            -- steps: reset, one access, and the configuration steps
//   tagctrl_main_vseq.svh        -- turns the knobs into a run

package tagctrl_seq_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;
  import tagctrl_ral_pkg::*;
  import tagctrl_env_pkg::*;

  typedef class tagctrl_access_seq;

  `include "tagctrl_seq_cfg.svh"
  `include "tagctrl_op.svh"
  `include "tagctrl_base_seq.svh"
  `include "tagctrl_access_seq.svh"
  `include "tagctrl_reset_seq.svh"
  `include "tagctrl_cfg_program_seq.svh"
  `include "tagctrl_cfg_command_seq.svh"
  `include "tagctrl_cfg_await_seq.svh"
  `include "tagctrl_cfg_walk_seq.svh"
  `include "tagctrl_main_vseq.svh"
endpackage
