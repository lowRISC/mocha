// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef AXI4_VIP_SEQUENCER_SVH
`define AXI4_VIP_SEQUENCER_SVH

class axi4_vip_sequencer extends uvm_sequencer #(axi4_vip_item);

  `uvm_component_utils(axi4_vip_sequencer)

  // External Method Declarations
  extern function new(string name, uvm_component parent);

endclass : axi4_vip_sequencer

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function axi4_vip_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

`endif // AXI4_VIP_SEQUENCER_SVH