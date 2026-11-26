// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Step: reset the DUT, then wait until the agents are also out of reset
  class tagctrl_reset_seq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_reset_seq)

    function new(string name = "tagctrl_reset_seq");
      super.new(name);
    endfunction

    task body();
      int unsigned stable = 0;
      p_sequencer.cfg.clk_rst_vif.apply_reset();
      for (int unsigned waited = 0; stable < 20; waited++) begin
        if (waited > 10000) `uvm_fatal(get_full_name(), "Reset never released")
        p_sequencer.cfg.clk_rst_vif.wait_clks(1);
        stable = (p_sequencer.agent_rst_vif.rst_n === 1'b1) ? stable + 1 : 0;
      end
    endtask
  endclass
