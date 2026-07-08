// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Abstract base for a monitored AXI transaction. The concrete items are
// axi_mon_write_item (AW + W beats + B) and axi_mon_read_item (AR + R beats); the
// base exists only so the monitor's analysis ports and the scoreboard can carry
// either through a single handle.
//
// The accessors below are the direction-agnostic view the scoreboard's routing needs
// (address decode, ID keying). Direction-specific fields (attributes, data, response)
// live on the concrete types and are reached by $cast where the scoreboard genuinely
// does different work per direction.

virtual class axi_mon_item extends uvm_sequence_item;

  extern function new(string name = "");

  // Request-phase AXI ID (awid / arid).
  pure virtual function bit [31:0] get_id();

  // Request-phase address (awaddr / araddr).
  pure virtual function bit [63:0] get_addr();

  // Transaction direction (implied by the concrete type).
  pure virtual function axi_dir_e get_dir();

  // Clone and return the result already cast to the axi_mon_item base handle. Relies on
  // the concrete type's factory registration + field automation, so it yields the right
  // dynamic type without each child reimplementing it.
  extern virtual function axi_mon_item item_clone();

endclass : axi_mon_item

function axi_mon_item::new(string name = "");
  super.new(name);
endfunction : new

function axi_mon_item axi_mon_item::item_clone();
  $cast(item_clone, clone());
endfunction : item_clone
