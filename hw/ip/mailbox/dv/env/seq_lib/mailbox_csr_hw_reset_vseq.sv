// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Read every readable register on both ports straight after reset and check its reset value,
// including the volatile STATUS, ERROR, IRQS and IRQP fields. IRQS reads 0x3 instead of 0x0 until
// #754 is fixed.
class mailbox_csr_hw_reset_vseq extends mailbox_csr_base_vseq;
  `uvm_object_utils(mailbox_csr_hw_reset_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : mailbox_csr_hw_reset_vseq


function mailbox_csr_hw_reset_vseq::new(string name = "");
  super.new(name);
endfunction : new

task mailbox_csr_hw_reset_vseq::body();
  foreach (cfg.ral[i]) begin
    uvm_reg       regs[$];
    uvm_reg_field fields[$];
    uvm_reg_field unchecked[$];

    cfg.ral[i].get_fields(fields);
    foreach (fields[j]) begin
      if (fields[j].get_compare() == UVM_NO_CHECK) begin
        unchecked.push_back(fields[j]);
        fields[j].set_compare(UVM_CHECK);
      end
    end

    get_readable_regs(mailbox_port_e'(i), CsrHwResetTest, regs);
    foreach (regs[j]) begin
      uvm_status_e status;

      regs[j].mirror(status, UVM_CHECK, .parent(this));
      check_status(status, regs[j], "Reset read of");
    end

    // Restore compare settings because V1 does not predict volatile fields during activity
    foreach (unchecked[j]) begin
      unchecked[j].set_compare(UVM_NO_CHECK);
    end
  end
endtask : body
