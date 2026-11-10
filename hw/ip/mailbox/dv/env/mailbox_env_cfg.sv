// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class mailbox_env_cfg extends uvm_object;
  `uvm_object_utils(mailbox_env_cfg)

  virtual clk_rst_if clk_rst_vif;

  // irq_o of the DUT, one bit per port
  virtual pins_if #(NumPorts) intr_vif;

  // Per-port register models at the Mocha base addresses
  mailbox_reg_block ral[NumPorts];

  // Tests set the minimum number of checked MBOXR words to prevent a pass without data checks
  int unsigned min_checked_words;

  // Build the coverage model when +en_cov is set
  bit en_cov;

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods
  // Build and lock both register blocks
  extern function void initialize();
endclass : mailbox_env_cfg


function mailbox_env_cfg::new(string name = "");
  super.new(name);
endfunction : new

function void mailbox_env_cfg::initialize();
  uvm_reg_addr_t base_addr[NumPorts];

  base_addr[PortMain] = uvm_reg_addr_t'(top_pkg::MailboxBase);
  base_addr[PortExt]  = uvm_reg_addr_t'(top_pkg::MailboxExtBaseAddr);
  foreach (ral[i]) begin
    ral[i] = mailbox_reg_block::type_id::create({"ral_", PortName[i]});
    ral[i].build(base_addr[i]);
    ral[i].lock_model();
  end
endfunction : initialize
