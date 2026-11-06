// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Pick the registers each CSR test accesses. A register excluded by a tag in data/mailbox.hjson is
// left out whole.
class mailbox_csr_base_vseq extends mailbox_base_vseq;
  `uvm_object_utils(mailbox_csr_base_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods
  // Return the registers of port that test can write and read back
  extern function void get_rw_regs(mailbox_port_e port,
                                   csr_test_type_e test,
                                   output uvm_reg regs[$]);

  // Return the registers of port that test can read
  extern function void get_readable_regs(mailbox_port_e port,
                                         csr_test_type_e test,
                                         output uvm_reg regs[$]);

  // Return a mask of rg's defined fields
  extern function uvm_reg_data_t get_field_mask(uvm_reg rg);

  // Report a failed RAL access
  extern function void check_status(uvm_status_e status, uvm_reg rg, string what);
endclass : mailbox_csr_base_vseq


function mailbox_csr_base_vseq::new(string name = "");
  super.new(name);
endfunction : new

function void mailbox_csr_base_vseq::get_rw_regs(mailbox_port_e port,
                                                 csr_test_type_e test,
                                                 output uvm_reg regs[$]);
  uvm_reg all_regs[$];

  regs.delete();
  cfg.ral[port].get_registers(all_regs);
  foreach (all_regs[i]) begin
    uvm_reg_field fields[$];
    bit           rw = 1'b1;

    all_regs[i].get_fields(fields);
    foreach (fields[j]) begin
      rw &= (fields[j].get_access() == "RW" || fields[j].get_access() == "W1C");
    end
    if (rw && !cfg.ral[port].get_excl_item().is_excl(all_regs[i], CsrExclAll, test)) begin
      regs.push_back(all_regs[i]);
    end
  end
endfunction : get_rw_regs

function void mailbox_csr_base_vseq::get_readable_regs(mailbox_port_e port,
                                                       csr_test_type_e test,
                                                       output uvm_reg regs[$]);
  uvm_reg all_regs[$];

  regs.delete();
  cfg.ral[port].get_registers(all_regs);
  foreach (all_regs[i]) begin
    uvm_reg_field fields[$];
    bit           readable = 1'b1;

    all_regs[i].get_fields(fields);
    foreach (fields[j]) begin
      readable &= (fields[j].get_access() != "WO");
    end
    if (readable && !cfg.ral[port].get_excl_item().is_excl(all_regs[i], CsrExclAll, test)) begin
      regs.push_back(all_regs[i]);
    end
  end
endfunction : get_readable_regs

function uvm_reg_data_t mailbox_csr_base_vseq::get_field_mask(uvm_reg rg);
  uvm_reg_field  fields[$];
  uvm_reg_data_t mask = 0;

  rg.get_fields(fields);
  foreach (fields[i]) begin
    mask |= ((uvm_reg_data_t'(1) << fields[i].get_n_bits()) - 1) << fields[i].get_lsb_pos();
  end
  return mask;
endfunction : get_field_mask

function void mailbox_csr_base_vseq::check_status(uvm_status_e status, uvm_reg rg, string what);
  if (status != UVM_IS_OK) begin
    `uvm_error(`gfn, $sformatf("%0s %0s returned %0s", what, rg.get_full_name(), status.name()))
  end
endfunction : check_status
