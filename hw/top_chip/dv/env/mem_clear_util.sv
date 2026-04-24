// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Simple memory-clearing class that overcomes the byte-directed assumptions of `mem_bkdr_util`
class mem_clear_util extends uvm_object;
  // Hierarchical path to the memory.
  protected string path;

  // The depth of the memory.
  protected int unsigned depth;

  // The width of the memory.
  protected int unsigned width;

  extern function new(string name = "", string path, int unsigned depth, longint unsigned n_bits);
  extern function void clear_mem();
endclass : mem_clear_util

function mem_clear_util::new(string name = "", string path, int unsigned depth, longint unsigned n_bits);
  this.path  = path;
  this.depth = depth;
  this.width = n_bits / depth;
endfunction : new

function void mem_clear_util::clear_mem();
  for (int unsigned index = 0; index < depth; index++) begin
    bit res = uvm_hdl_deposit($sformatf("%0s[%0d]", path, index), '0);
    `DV_CHECK_EQ(res, 1, $sformatf("uvm_hdl_deposit failed at index %0d", index))
  end
endfunction : clear_mem
