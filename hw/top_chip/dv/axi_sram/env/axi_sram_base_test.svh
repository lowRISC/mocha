// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Builds the env and runs the vseq named by +UVM_TEST_SEQ on m_env.m_vseqr.
  class axi_sram_base_test extends uvm_test;
    `uvm_component_utils(axi_sram_base_test)

    axi_sram_env m_env;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_env = axi_sram_env::type_id::create("m_env", this);
    endfunction

    task run_phase(uvm_phase phase);
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
    endtask

    // Emit the pass/fail status line, from the UVM error and fatal tallies.
    function void report_phase(uvm_phase phase);
      uvm_report_server rs = uvm_report_server::get_server();
      super.report_phase(phase);
      dv_test_status_pkg::dv_test_status((rs.get_severity_count(UVM_ERROR) == 0) &&
                                         (rs.get_severity_count(UVM_FATAL) == 0));
    endfunction

  endclass
