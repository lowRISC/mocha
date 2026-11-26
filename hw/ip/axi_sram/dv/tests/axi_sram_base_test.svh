// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Builds the env and runs the vseq named by +UVM_TEST_SEQ on m_env.m_vseqr.
class axi_sram_base_test extends uvm_test;
  `uvm_component_utils(axi_sram_base_test)

  axi_sram_env     m_env;
  axi_sram_env_cfg cfg;

  // Overridable with +test_timeout_ns=N.
  longint unsigned test_timeout_ns = 10_000_000;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void end_of_elaboration_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  // Emit the pass/fail status line, from the UVM error and fatal tallies.
  extern function void report_phase(uvm_phase phase);
endclass : axi_sram_base_test


function axi_sram_base_test::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sram_base_test::build_phase(uvm_phase phase);
  super.build_phase(phase);

  cfg = axi_sram_env_cfg::type_id::create("cfg");
  if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "clk_rst_vif", cfg.clk_rst_vif)) begin
    `uvm_fatal(get_full_name(), "Cannot get clk_rst_vif from config_db")
  end
  if (!uvm_config_db#(axi_vif_t)::get(this, "", "vif", cfg.axi_vif)) begin
    `uvm_fatal(get_full_name(), "Cannot get the AXI bus (key \"vif\") from config_db")
  end
  void'($value$plusargs("en_cov=%0b", cfg.en_cov));

  // TODO(lowRISC/mocha#779): X on an idle channel's payload fires DataKnown_A in the DUT.
  cfg.axi_vif.set_drive_x_when_idle(1'b0);

  m_env = axi_sram_env::type_id::create("m_env", this);
  m_env.cfg = cfg;
endfunction : build_phase

function void axi_sram_base_test::end_of_elaboration_phase(uvm_phase phase);
  super.end_of_elaboration_phase(phase);
  void'($value$plusargs("test_timeout_ns=%0d", test_timeout_ns));
  uvm_top.set_timeout(test_timeout_ns * 1ns);
endfunction : end_of_elaboration_phase

task axi_sram_base_test::run_phase(uvm_phase phase);
  string       test_seq_s;
  uvm_sequence test_seq;

  if (!$value$plusargs("UVM_TEST_SEQ=%0s", test_seq_s)) begin
    `uvm_fatal(get_full_name(), "No +UVM_TEST_SEQ given")
  end
  if (!$cast(test_seq,
             uvm_factory::get().create_object_by_name(test_seq_s, "", test_seq_s))) begin
    `uvm_fatal(get_full_name(), {"Cannot create sequence ", test_seq_s})
  end
  phase.raise_objection(this);
  test_seq.start(m_env.m_vseqr);
  phase.drop_objection(this);
endtask : run_phase

function void axi_sram_base_test::report_phase(uvm_phase phase);
  uvm_report_server rs = uvm_report_server::get_server();
  super.report_phase(phase);
  dv_test_status_pkg::dv_test_status((rs.get_severity_count(UVM_ERROR) == 0) &&
                                     (rs.get_severity_count(UVM_FATAL) == 0));
endfunction : report_phase
