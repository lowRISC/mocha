// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Build the environment and run the virtual sequence that +UVM_TEST_SEQ names
class mailbox_base_test extends uvm_test;
  `uvm_component_utils(mailbox_base_test)

  mailbox_env     env;
  mailbox_env_cfg cfg;

  // Simulation watchdog, not a design limit; override with +test_timeout_ns
  uint64 test_timeout_ns = 10_000_000;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
endclass : mailbox_base_test


function mailbox_base_test::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void mailbox_base_test::build_phase(uvm_phase phase);
  // DVSim uses this report server's summary to determine pass or fail
  dv_report_server report_server = new();

  uvm_report_server::set_server(report_server);

  cfg = mailbox_env_cfg::type_id::create("cfg");
  if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", cfg.clk_rst_vif)) begin
    `uvm_fatal(`gfn, "failed to get clk_rst_vif from uvm_config_db")
  end
  cfg.initialize();

  env = mailbox_env::type_id::create("env", this);
  env.cfg = cfg;
endfunction : build_phase

function void mailbox_base_test::end_of_elaboration_phase(uvm_phase phase);
  void'($value$plusargs("test_timeout_ns=%0d", test_timeout_ns));
  uvm_top.set_timeout(test_timeout_ns * 1ns);
endfunction : end_of_elaboration_phase

task mailbox_base_test::run_phase(uvm_phase phase);
  string       test_seq_name;
  uvm_sequence test_seq;

  if (!$value$plusargs("UVM_TEST_SEQ=%0s", test_seq_name)) begin
    `uvm_fatal(`gfn, "no sequence given with +UVM_TEST_SEQ")
  end
  test_seq = create_seq_by_name(test_seq_name);
  // Let constraints access the configuration during randomization
  test_seq.set_sequencer(env.m_vsqr);
  `DV_CHECK_RANDOMIZE_FATAL(test_seq)

  phase.raise_objection(this);
  `uvm_info(`gfn, {"Starting test sequence ", test_seq_name}, UVM_MEDIUM)
  test_seq.start(env.m_vsqr);
  `uvm_info(`gfn, {"Finished test sequence ", test_seq_name}, UVM_MEDIUM)
  phase.drop_objection(this);
endtask : run_phase
