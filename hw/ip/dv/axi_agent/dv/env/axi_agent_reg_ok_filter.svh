// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Pass only transactions converted to UVM_IS_OK by the adapter. uvm_reg_predictor ignores status
// when updating mirrors, so failed writes must be filtered out.

class axi_agent_reg_ok_filter extends uvm_subscriber #(axi_mon_item);
  `uvm_component_utils(axi_agent_reg_ok_filter)

  // Publish as uvm_sequence_item for uvm_reg_predictor
  uvm_analysis_port #(uvm_sequence_item) m_out_port;

  // Set the adapter before run_phase
  axi_reg_adapter m_adapter;

  // The number of transactions held back
  int unsigned m_num_dropped;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void write(axi_mon_item t);
endclass : axi_agent_reg_ok_filter


function axi_agent_reg_ok_filter::new(string name, uvm_component parent);
  super.new(name, parent);
  m_out_port = new("m_out_port", this);
endfunction : new

function void axi_agent_reg_ok_filter::write(axi_mon_item t);
  uvm_reg_bus_op rw;

  m_adapter.bus2reg(t, rw);
  if (rw.status == UVM_IS_OK) begin
    m_out_port.write(t);
  end else begin
    m_num_dropped++;
  end
endfunction : write
