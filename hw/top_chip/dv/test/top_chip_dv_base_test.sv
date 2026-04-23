// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_base_test extends uvm_test;
  top_chip_dv_env env;

  `uvm_component_utils(top_chip_dv_base_test)

  uint   max_quit_count  = 1;
  uint64 test_timeout_ns = 200_000_000; // 200ms

  // Standard SV/UVM methods
  extern function new(string name = "", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  // Class specific methods
  extern task run_test();
  extern task run_seq(string test_seq_s);
endclass : top_chip_dv_base_test


function top_chip_dv_base_test::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void top_chip_dv_base_test::build_phase(uvm_phase phase);
  dv_report_server m_dv_report_server = new();
  uvm_report_server::set_server(m_dv_report_server);

  super.build_phase(phase);

  env     = top_chip_dv_env::type_id::create("env", this);
  env.cfg = top_chip_dv_env_cfg::type_id::create("cfg", this);
  env.cfg.initialize();
endfunction : build_phase

function void top_chip_dv_base_test::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
endfunction : connect_phase

function void top_chip_dv_base_test::end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  void'($value$plusargs("max_quit_count=%0d", max_quit_count));
  set_max_quit_count(max_quit_count);
  void'($value$plusargs("test_timeout_ns=%0d", test_timeout_ns));
  uvm_top.set_timeout((test_timeout_ns * 1ns));
endfunction : end_of_elaboration_phase

task top_chip_dv_base_test::run_phase(uvm_phase phase);
  env.load_memories();
  phase.raise_objection(this);
  run_test();
  phase.drop_objection(this);
endtask : run_phase

task top_chip_dv_base_test::run_test();
  string test_seq_s;

  if (!$value$plusargs("UVM_TEST_SEQ=%0s", test_seq_s)) begin
    `uvm_fatal(`gfn, "Sequence name was not provided via +UVM_TEST_SEQ, cannot run test")
  end

  fork : isolation_work
    fork
      begin
        run_seq(test_seq_s);
      end
      begin
        repeat (env.cfg.sys_timeout_cycles) env.cfg.sys_clk_vif.wait_clks(1);
        `uvm_fatal(`gfn, $sformatf("Reached system cycle timeout of %d", env.cfg.sys_timeout_cycles))
      end
    join_any

    disable fork;
  join
endtask : run_test

task top_chip_dv_base_test::run_seq(string test_seq_s);
  uvm_sequence test_seq = create_seq_by_name(test_seq_s);

  // Setting the sequencer before the sequence is randomized is mandatory. We do this so that the
  // sequence has access to the UVM environment's cfg handle via the p_sequencer handle within the
  // randomization constraints.
  test_seq.set_sequencer(env.top_vsqr);
  `DV_CHECK_RANDOMIZE_FATAL(test_seq)

  `uvm_info(`gfn, {"Starting test sequence ", test_seq_s}, UVM_MEDIUM)
  test_seq.start(env.top_vsqr);
  `uvm_info(`gfn, {"Finished test sequence ", test_seq_s}, UVM_MEDIUM)
endtask : run_seq
