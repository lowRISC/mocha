// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class mailbox_base_vseq extends uvm_sequence;
  `uvm_object_utils(mailbox_base_vseq)
  `uvm_declare_p_sequencer(mailbox_virtual_sequencer)

  mailbox_env_cfg cfg;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task pre_start();
  // Hook for the test vseqs to override with their stimulus. Empty here, so the base vseq only
  // resets the DUT in pre_start.
  extern task body();

  // Class specific methods
  // Reset the DUT and both register models
  extern task dut_init();

  // The helpers below omit the parent so the map creates one per access. UVM 1.2 takes the parent's
  // first response, so sharing a parent across concurrent port accesses can swap responses.
  extern task write_mboxw(mailbox_port_e port, uvm_reg_data_t data);

  // Read MBOXR for the scoreboard to check
  extern task read_mboxr(mailbox_port_e port);

  // Read STATUS for the scoreboard to check
  extern task read_status(mailbox_port_e port);
endclass : mailbox_base_vseq


function mailbox_base_vseq::new(string name = "");
  super.new(name);
endfunction : new

task mailbox_base_vseq::pre_start();
  super.pre_start();
  cfg = p_sequencer.cfg;
  dut_init();
endtask : pre_start

task mailbox_base_vseq::body();
endtask : body

task mailbox_base_vseq::dut_init();
  cfg.clk_rst_vif.apply_reset();
  // Let the drivers see reset deassert before the first access
  wait (cfg.clk_rst_vif.rst_n === 1'b1);
  cfg.clk_rst_vif.wait_clks(1);
  foreach (cfg.ral[i]) begin
    cfg.ral[i].reset();
  end
endtask : dut_init

task mailbox_base_vseq::write_mboxw(mailbox_port_e port, uvm_reg_data_t data);
  uvm_status_e status;

  cfg.ral[port].mboxw.write(status, data);
endtask : write_mboxw

task mailbox_base_vseq::read_mboxr(mailbox_port_e port);
  uvm_status_e   status;
  uvm_reg_data_t data;

  cfg.ral[port].mboxr.read(status, data);
endtask : read_mboxr

task mailbox_base_vseq::read_status(mailbox_port_e port);
  uvm_status_e   status;
  uvm_reg_data_t data;

  cfg.ral[port].status.read(status, data);
endtask : read_status
