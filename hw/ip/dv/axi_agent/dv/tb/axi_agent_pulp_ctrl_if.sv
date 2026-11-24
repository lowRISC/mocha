// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Control testbench-owned pulp_axi classes from sequences. For random managers, set
// n_reads/n_writes and raise start. The testbench clears start and increments runs_done when
// finished. For directed AXI4-Lite accesses, push one entry per op_* queue. The testbench executes
// them in order and increments ops_done.

interface axi_agent_pulp_ctrl_if;

  int unsigned n_reads;
  int unsigned n_writes;
  bit          start;
  int unsigned runs_done;

  bit          op_write[$];
  bit [31:0]   op_addr[$];
  bit [63:0]   op_wdata[$];
  bit [7:0]    op_wstrb[$];
  int unsigned ops_done;

  function automatic void push_op(bit write, bit [31:0] addr, bit [63:0] wdata, bit [7:0] wstrb);
    op_write.push_back(write);
    op_addr.push_back(addr);
    op_wdata.push_back(wdata);
    op_wstrb.push_back(wstrb);
  endfunction : push_op

endinterface : axi_agent_pulp_ctrl_if
