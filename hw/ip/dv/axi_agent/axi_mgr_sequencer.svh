// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Sequencer for axi_transfer_seq and its subclasses, with no driver. Provides the axi_mgr_agent
// channel sequencers, bus, and write and read response routers that deliver responses by ID.

class axi_mgr_sequencer extends uvm_sequencer;
  `uvm_component_utils(axi_mgr_sequencer)

  write_request_sequencer_t  m_write_request_sequencer;
  write_data_sequencer_t     m_write_data_sequencer;
  write_response_sequencer_t m_write_response_sequencer;
  read_request_sequencer_t   m_read_request_sequencer;
  read_data_sequencer_t      m_read_data_sequencer;

  axi_response_router m_write_response_router;
  axi_response_router m_read_response_router;

  axi_vif_t m_vif;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
endclass: axi_mgr_sequencer


function axi_mgr_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction: new
