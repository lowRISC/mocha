// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Hub a virtual sequence runs on: handles to the active agent's per-channel AXI
  // sequencers + response routers, plus the clk_rst_if vif (clock/reset is
  // method-driven, not a sequencer). Wired up in axi_sram_env::connect_phase.
  class axi_sram_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(axi_sram_virtual_sequencer)

    // Real AXI channel sequencers (from the active agent).
    write_request_sequencer_t  write_request_seqr;
    write_data_sequencer_t     write_data_seqr;
    write_response_sequencer_t write_response_seqr;
    read_request_sequencer_t   read_request_seqr;
    read_data_sequencer_t      read_data_seqr;

    // ID-keyed B/R response routers used by the burst vseqs.
    axi_response_router        write_response_router;
    axi_response_router        read_response_router;

    // Clock/reset interface (method-driven: apply_reset, wait_clks, ...).
    virtual clk_rst_if         clk_rst_vif;

    // Passive clk_rst_if on the agent's own clock/reset domain (published by the
    // axi_vip_if), used to observe when the DUT-side reset has settled without a
    // DUT hierarchy path.
    virtual clk_rst_if         agent_rst_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass
