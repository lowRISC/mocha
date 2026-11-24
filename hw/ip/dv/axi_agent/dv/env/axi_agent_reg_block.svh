// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// 32-bit read-write registers at word offsets in subordinate memory. Single-field registers are
// followed by registers with individually writable byte fields to exercise single-lane strobes.

class axi_agent_reg extends uvm_reg;
  `uvm_object_utils(axi_agent_reg)

  rand uvm_reg_field value;

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods
  extern function void build();
endclass : axi_agent_reg


function axi_agent_reg::new(string name = "");
  super.new(name, 32, UVM_NO_COVERAGE);
endfunction : new

function void axi_agent_reg::build();
  value = uvm_reg_field::type_id::create("value");
  value.configure(this, 32, 0, "RW", 0, 32'h0, 1'b0, 1'b1, 1'b1);
endfunction : build


class axi_agent_byte_reg extends uvm_reg;
  `uvm_object_utils(axi_agent_byte_reg)

  rand uvm_reg_field bytes[4];

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods
  extern function void build();
endclass : axi_agent_byte_reg


function axi_agent_byte_reg::new(string name = "");
  super.new(name, 32, UVM_NO_COVERAGE);
endfunction : new

function void axi_agent_byte_reg::build();
  foreach (bytes[i]) begin
    bytes[i] = uvm_reg_field::type_id::create($sformatf("byte%0d", i));
    bytes[i].configure(this, 8, 8 * i, "RW", 0, 8'h0, 1'b0, 1'b1, 1'b1);
  end
endfunction : build


class axi_agent_reg_block extends uvm_reg_block;
  `uvm_object_utils(axi_agent_reg_block)

  rand axi_agent_reg      regs[];
  rand axi_agent_byte_reg byte_regs[];

  // Registers at err_offset, where the subordinate answers with an error
  rand axi_agent_reg      err_regs[];

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  // Build num_regs at 4-byte offsets from base_addr, then num_byte_regs byte-field registers, plus
  // num_err_regs at err_offset. Use a 32-bit map.
  extern function void build(uvm_reg_addr_t base_addr, int unsigned num_regs,
                             int unsigned num_byte_regs = 0, int unsigned num_err_regs = 0,
                             uvm_reg_addr_t err_offset = 0);
endclass : axi_agent_reg_block


function axi_agent_reg_block::new(string name = "");
  super.new(name, UVM_NO_COVERAGE);
endfunction : new

function void axi_agent_reg_block::build(uvm_reg_addr_t base_addr, int unsigned num_regs,
                                         int unsigned num_byte_regs = 0,
                                         int unsigned num_err_regs = 0,
                                         uvm_reg_addr_t err_offset = 0);
  default_map = create_map("default_map", base_addr, 4, UVM_LITTLE_ENDIAN);
  regs = new[num_regs];
  foreach (regs[i]) begin
    regs[i] = axi_agent_reg::type_id::create($sformatf("reg%0d", i));
    regs[i].configure(this);
    regs[i].build();
    default_map.add_reg(regs[i], 4 * i, "RW");
  end
  byte_regs = new[num_byte_regs];
  foreach (byte_regs[i]) begin
    byte_regs[i] = axi_agent_byte_reg::type_id::create($sformatf("byte_reg%0d", i));
    byte_regs[i].configure(this);
    byte_regs[i].build();
    default_map.add_reg(byte_regs[i], 4 * (num_regs + i), "RW");
  end
  err_regs = new[num_err_regs];
  foreach (err_regs[i]) begin
    err_regs[i] = axi_agent_reg::type_id::create($sformatf("err_reg%0d", i));
    err_regs[i].configure(this);
    err_regs[i].build();
    default_map.add_reg(err_regs[i], err_offset + 4 * i, "RW");
  end
  lock_model();
endfunction : build
