// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Every sequence of the package runs on the virtual sequencer of an active tagctrl_env. None of
  // them checks what the DUT returns: that is the scoreboard's job.
  class tagctrl_base_seq extends uvm_sequence;
    `uvm_object_utils(tagctrl_base_seq)
    `uvm_declare_p_sequencer(tagctrl_virtual_sequencer)

    // Clock cycles an access may take before the DUT counts as hung
    localparam int unsigned MaxOpClks = 10000;

    function new(string name = "tagctrl_base_seq");
      super.new(name);
    endfunction

    // Run a step on the same sequencer as this sequence
    protected task run_step(tagctrl_base_seq step);
      step.start(p_sequencer, this);
    endtask

    // Send one access and wait for its response. Read data comes back in op.rdata.
    protected task run_op(tagctrl_op op);
      tagctrl_access_seq step = tagctrl_access_seq::type_id::create("access");
      step.op = op;
      run_step(step);
    endtask

    // A single 64-bit access to the configuration subordinate
    protected task cfg_access(bit write, bit [11:0] offset, bit [63:0] wdata = 0,
                              output bit [63:0] rdata);
      tagctrl_op op = tagctrl_op::type_id::create("cfg_op");
      if (!op.randomize() with { port == PortCfg;
                                 write == local::write;
                                 addr == offset;
                                 wdata[0] == local::wdata; }) begin
        `uvm_fatal(get_full_name(), $sformatf("Cannot randomize an access to 0x%03h", offset))
      end
      run_op(op);
      rdata = write ? 0 : op.rdata[0];
    endtask
  endclass
