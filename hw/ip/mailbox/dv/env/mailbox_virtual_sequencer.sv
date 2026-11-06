// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class mailbox_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(mailbox_virtual_sequencer)

  mailbox_env_cfg cfg;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
endclass : mailbox_virtual_sequencer


function mailbox_virtual_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new
