// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // The transfer sequencers of the two manager agents, the register model, and the clock and
  // reset. Built only when the env is active, and wired up in tagctrl_env::connect_phase.
  class tagctrl_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(tagctrl_virtual_sequencer)

    // The register model and the testbench clock and reset generator. Use the generator to
    // apply a reset or wait for clocks.
    tagctrl_env_cfg cfg;

    // Drive the configuration and the tagged subordinate
    axi_txn_sequencer_t cfg_seqr;
    axi_txn_sequencer_t tag_seqr;

    // The clock and reset the agents run on. Observe only.
    virtual clk_rst_if  agent_rst_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass
