// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Serialize W bursts in AW order without delaying the next AW until the previous W burst ends (AMBA
// AXI H.c A5.2.2). Call start_aw before AW and aw_done after it; send W beats between wait_for_w
// and w_done. Bursts cannot interleave. UVM 1.2 sequencer locks cannot enforce this: releasing a
// lock grants all waiting lock requests at once.

class axi_mgr_write_data_sequencer extends uvm_sequencer #(axi_write_data_item, axi_status_item);
  `uvm_component_utils(axi_mgr_write_data_sequencer)

  // Hold from start_aw to aw_done so places are taken in AW order
  local semaphore m_aw_turn;

  // Next place to hand out and the place whose W beats may go
  local int unsigned m_next_place;
  local int unsigned m_w_place;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods

  // Wait for the AW channel, then take the next place in the write order
  extern task start_aw(output int unsigned place);

  // Let the next write send its AW request
  extern function void aw_done();

  // Wait until every write with an earlier place has sent its W beats
  extern task wait_for_w(int unsigned place);

  // Let the write with the next place send its W beats
  extern function void w_done();
endclass: axi_mgr_write_data_sequencer


function axi_mgr_write_data_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
  m_aw_turn = new(1);
endfunction: new

task axi_mgr_write_data_sequencer::start_aw(output int unsigned place);
  m_aw_turn.get(1);
  place = m_next_place++;
endtask: start_aw

function void axi_mgr_write_data_sequencer::aw_done();
  m_aw_turn.put(1);
endfunction: aw_done

task axi_mgr_write_data_sequencer::wait_for_w(int unsigned place);
  wait (m_w_place == place);
endtask: wait_for_w

function void axi_mgr_write_data_sequencer::w_done();
  m_w_place++;
endfunction: w_done
