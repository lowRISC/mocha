// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Builds the env, randomises tagctrl_seq_cfg (or the knob class a test overrides it with) and
  // runs the sequence the test names in test_seq_s on it. +UVM_TEST_SEQ may name the sequence
  // too, but only the same one.
  class tagctrl_base_test extends uvm_test;
    `uvm_component_utils(tagctrl_base_test)

    tagctrl_env     env;
    tagctrl_env_cfg cfg;

    // The sequence the test runs
    string test_seq_s = "tagctrl_main_vseq";

    // Overridable with +test_timeout_ns=N
    longint unsigned test_timeout_ns = 20_000_000;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      cfg = tagctrl_env_cfg::type_id::create("cfg");
      if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", cfg.clk_rst_vif)) begin
        `uvm_fatal(get_full_name(), "Cannot get clk_rst_vif from config_db")
      end
      cfg.initialize();
      configure_env(cfg);
      env     = tagctrl_env::type_id::create("env", this);
      env.cfg = cfg;
    endfunction

    // A test sets the env switches it needs here
    virtual function void configure_env(tagctrl_env_cfg env_cfg);
    endfunction

    function void end_of_elaboration_phase(uvm_phase phase);
      super.end_of_elaboration_phase(phase);
      void'($value$plusargs("test_timeout_ns=%0d", test_timeout_ns));
      uvm_top.set_timeout(test_timeout_ns * 1ns);
    endfunction

    task run_phase(uvm_phase phase);
      string            plusarg_seq;
      uvm_object        obj;
      tagctrl_main_vseq vseq;
      tagctrl_seq_cfg   seq_cfg;

      if ($value$plusargs("UVM_TEST_SEQ=%0s", plusarg_seq) && plusarg_seq != test_seq_s) begin
        `uvm_fatal(get_full_name(), {"+UVM_TEST_SEQ=", plusarg_seq, " but the test runs ",
                                     test_seq_s})
      end
      if (test_seq_s == "") `uvm_fatal(get_full_name(), "The test names no sequence")
      obj = uvm_factory::get().create_object_by_name(test_seq_s, "", test_seq_s);
      if (!$cast(vseq, obj)) `uvm_fatal(get_full_name(), {"Cannot create sequence ", test_seq_s})

      seq_cfg = tagctrl_seq_cfg::type_id::create("seq_cfg");
      if (!seq_cfg.randomize()) `uvm_fatal(get_full_name(), "Cannot randomize the knobs")
      `uvm_info(get_full_name(), {"Knobs:\n", seq_cfg.sprint()}, UVM_LOW)
      vseq.cfg = seq_cfg;

      phase.raise_objection(this);
      vseq.start(env.m_vseqr);
      phase.drop_objection(this);
    endtask

    // Emit the pass/fail status line from the UVM error and fatal tallies
    function void report_phase(uvm_phase phase);
      uvm_report_server rs = uvm_report_server::get_server();
      super.report_phase(phase);
      dv_test_status_pkg::dv_test_status((rs.get_severity_count(UVM_ERROR) == 0) &&
                                         (rs.get_severity_count(UVM_FATAL) == 0));
    endfunction
  endclass
