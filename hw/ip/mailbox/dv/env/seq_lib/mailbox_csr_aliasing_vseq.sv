// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check for register aliasing across both ports by changing one register at a time in random order
// and comparing all readable registers after each write. The scoreboard also checks each STATUS
// read.
class mailbox_csr_aliasing_vseq extends mailbox_csr_base_vseq;
  `uvm_object_utils(mailbox_csr_aliasing_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods
  // Choose a value predicted to differ from the mirror, except for volatile fields
  extern function uvm_reg_data_t pick_new_value(uvm_reg rg);
endclass : mailbox_csr_aliasing_vseq


function mailbox_csr_aliasing_vseq::new(string name = "");
  super.new(name);
endfunction : new

task mailbox_csr_aliasing_vseq::body();
  uvm_reg targets[$];
  uvm_reg readable[$];

  foreach (cfg.ral[i]) begin
    uvm_reg port_regs[$];

    get_rw_regs(mailbox_port_e'(i), CsrAliasingTest, port_regs);
    targets = {targets, port_regs};
    get_readable_regs(mailbox_port_e'(i), CsrAliasingTest, port_regs);
    readable = {readable, port_regs};
  end
  targets.shuffle();

  foreach (targets[i]) begin
    uvm_status_e status;

    targets[i].write(status, pick_new_value(targets[i]), .parent(this));
    check_status(status, targets[i], "Write to");
    foreach (readable[j]) begin
      readable[j].mirror(status, UVM_CHECK, .parent(this));
      check_status(status, readable[j], "Read of");
    end
  end
endtask : body

function uvm_reg_data_t mailbox_csr_aliasing_vseq::pick_new_value(uvm_reg rg);
  mailbox_reg_block ral;
  uvm_reg_field     fields[$];
  uvm_reg_data_t    mask = get_field_mask(rg);
  uvm_reg_data_t    value;
  uvm_reg_data_t    predicted;
  bit               is_volatile = 1'b0;

  `downcast(ral, rg.get_parent())
  rg.get_fields(fields);
  foreach (fields[i]) begin
    is_volatile |= fields[i].is_volatile();
  end

  do begin
    `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(value, (value & ~mask) == 0;)
    predicted = (rg == ral.wirqt || rg == ral.rirqt) ? mailbox_clamp_threshold(value) : value;
  end while (!is_volatile && predicted == rg.get_mirrored_value());
  return value;
endfunction : pick_new_value
