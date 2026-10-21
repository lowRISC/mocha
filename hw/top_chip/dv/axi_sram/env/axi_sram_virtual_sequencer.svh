// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Handles to the active agent's per-channel AXI sequencers + response routers, 
  // plus the clk_rst_if vif. Wired up in axi_sram_env::connect_phase.
  class axi_sram_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(axi_sram_virtual_sequencer)

    // Real AXI channel sequencers (from the agent).
    write_request_sequencer_t  write_request_seqr;
    write_data_sequencer_t     write_data_seqr;
    write_response_sequencer_t write_response_seqr;
    read_request_sequencer_t   read_request_seqr;
    read_data_sequencer_t      read_data_seqr;

    // ID-keyed B/R response routers used by the burst vseqs.
    axi_response_router        write_response_router;
    axi_response_router        read_response_router;

    // The testbench clock and reset generator. Use it to apply a reset or wait for clocks.
    virtual clk_rst_if         clk_rst_vif;

    // The clock and reset the AXI agent runs on, inside its axi_vip_if. Observe only.
    virtual clk_rst_if         agent_rst_vif;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass
