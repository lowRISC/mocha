// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitor for the shared AXI clock/reset (ACLK/ARESETn). AXI is a single-reset
// protocol, so one instance covers all five channels: it broadcasts an
// axi_reset_item on every reset state change.
//
// This is also the monitor that maintains cfg.in_reset, which is how the channel drivers observe
// reset (see dv_base_driver::reset_signals).

class axi_reset_monitor extends uvm_monitor;
  `uvm_component_utils(axi_reset_monitor);

  // A port that broadcasts an item on every reset state change.
  uvm_analysis_port #(axi_reset_item) m_analysis_port;

  // The agent config. This supplies the clock/reset interface being tracked and holds the in_reset
  // flag that this monitor maintains. Set this with set_cfg before run_phase.
  local axi_agent_cfg m_cfg;

  extern function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);

  extern function void set_cfg(axi_agent_cfg cfg);
endclass

function void axi_reset_monitor::set_cfg(axi_agent_cfg cfg);
  m_cfg = cfg;
endfunction

function axi_reset_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
  m_analysis_port = new("m_analysis_port", this);
endfunction

task axi_reset_monitor::run_phase(uvm_phase phase);
  if (m_cfg == null) begin
    `uvm_fatal(get_full_name(), "Cannot monitor interface: cfg is null.")
    return;
  end
  if (m_cfg.clk_rst_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot monitor interface: vif is null.")
    return;
  end

  wait(!$isunknown(m_cfg.clk_rst_vif.rst_n));
  forever begin
    axi_reset_item rst_item;
    bit rst_n_bit = bit'(m_cfg.clk_rst_vif.rst_n);

    // Update in_reset before broadcasting the item: the drivers wait on cfg.in_reset, so it must
    // already hold the new state by the time anything downstream reacts to the reset item.
    m_cfg.in_reset = !rst_n_bit;

    rst_item = axi_reset_item::type_id::create("rst_item");
    rst_item.m_in_reset = !rst_n_bit;
    m_analysis_port.write(rst_item);

    wait(m_cfg.clk_rst_vif.rst_n === !rst_n_bit);
  end
endtask
