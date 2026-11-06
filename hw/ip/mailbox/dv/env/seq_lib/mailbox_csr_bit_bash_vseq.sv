// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Run uvm_reg_single_bit_bash_seq on both ports' R/W registers, treating reserved bits as read-only
// zeros and predicting the WIRQT/RIRQT clamp. Skip volatile IRQS fields, which V1 does not predict;
// bash only its reserved bits.
class mailbox_csr_bit_bash_vseq extends mailbox_csr_base_vseq;
  `uvm_object_utils(mailbox_csr_bit_bash_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : mailbox_csr_bit_bash_vseq


function mailbox_csr_bit_bash_vseq::new(string name = "");
  super.new(name);
endfunction : new

task mailbox_csr_bit_bash_vseq::body();
  uvm_reg_single_bit_bash_seq bit_bash_seq =
    uvm_reg_single_bit_bash_seq::type_id::create("bit_bash_seq");

  foreach (cfg.ral[i]) begin
    uvm_reg regs[$];

    // Writes to read-only registers answer SLVERR and belong to V2 mailbox_access_errors
    get_rw_regs(mailbox_port_e'(i), CsrBitBashTest, regs);
    foreach (regs[j]) begin
      bit_bash_seq.rg = regs[j];
      bit_bash_seq.start(null, this);
    end
  end
endtask : body
