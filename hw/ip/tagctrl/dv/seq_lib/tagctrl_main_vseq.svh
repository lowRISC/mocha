// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Turns the knobs of cfg into one run: reset, an optional register walk, an optional
  // configuration and start, then random accesses one at a time, with the read-backs the knobs
  // ask for.
  class tagctrl_main_vseq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_main_vseq)

    // Set by the test before starting
    tagctrl_seq_cfg cfg;

    function new(string name = "tagctrl_main_vseq");
      super.new(name);
    endfunction

    task body();
      tagctrl_op written[$];
      if (cfg == null) `uvm_fatal(get_full_name(), "cfg is null")

      run_step(tagctrl_reset_seq::type_id::create("reset"));
      if (cfg.walk != WalkNone) walk();
      if (cfg.configure) configure_and_start();

      for (int unsigned i = 0; i < cfg.num_ops; i++) begin
        tagctrl_knob_op op = tagctrl_knob_op::type_id::create($sformatf("op_%0d", i));
        bit [63:0]      rdata;
        op.cfg = cfg;
        if (!op.randomize()) `uvm_fatal(get_full_name(), "Cannot randomize a random access")
        run_op(op);
        if (op.port == PortCfg && op.write && cfg.cfg_write_readback) begin
          cfg_access(1'b0, op.addr, , rdata);
        end
        if (op.port == PortTag && op.write) written.push_back(op);
      end

      if (cfg.tag_readback) foreach (written[i]) read_back(written[i]);
    endtask

    protected task walk();
      tagctrl_cfg_walk_seq step = tagctrl_cfg_walk_seq::type_id::create("walk");
      step.walk           = cfg.walk;
      step.covered_base   = cfg.covered_base;
      step.covered_top    = cfg.covered_top;
      step.tag_table_base = cfg.tag_table_base;
      run_step(step);
    endtask

    protected task configure_and_start();
      tagctrl_cfg_program_seq program_step = tagctrl_cfg_program_seq::type_id::create("program");
      tagctrl_cfg_command_seq start_step   = tagctrl_cfg_command_seq::type_id::create("start");
      program_step.covered_base   = cfg.covered_base;
      program_step.covered_top    = cfg.covered_top;
      program_step.tag_table_base = cfg.tag_table_base;
      run_step(program_step);
      start_step.command = CtrlStart;
      run_step(start_step);
      run_step(tagctrl_cfg_await_seq::type_id::create("await"));
    endtask

    // Read what a tagged write covered, the same way it was written
    protected task read_back(tagctrl_op wr);
      tagctrl_op rd = tagctrl_op::type_id::create("read_back");
      if (!rd.randomize() with { port == PortTag;
                                 !write;
                                 id == wr.id;
                                 addr == wr.addr;
                                 len == wr.len;
                                 size == wr.size;
                                 burst == wr.burst; }) begin
        `uvm_fatal(get_full_name(), {"Cannot randomize a read back of ", wr.convert2string()})
      end
      run_op(rd);
    endtask
  endclass
