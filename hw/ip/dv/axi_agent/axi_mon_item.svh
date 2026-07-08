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
  pure virtual function axi_id_t   get_id();

  // Request-phase address (awaddr / araddr).
  pure virtual function axi_addr_t get_addr();

  // Transaction direction (implied by the concrete type).
  pure virtual function axi_dir_e get_dir();

  // clone(), with the $cast to axi_mon_item done once here rather than at every call site.
  extern virtual function axi_mon_item item_clone();

endclass : axi_mon_item

function axi_mon_item::new(string name = "");
  super.new(name);
endfunction : new

function axi_mon_item axi_mon_item::item_clone();
  uvm_object obj;

  obj = clone();
  // A $cast from a null handle succeeds, so a failed clone would return null silently.
  `DV_CHECK_FATAL(obj != null, "clone() returned null")
  `DV_CHECK_FATAL($cast(item_clone, obj))
endfunction : item_clone
