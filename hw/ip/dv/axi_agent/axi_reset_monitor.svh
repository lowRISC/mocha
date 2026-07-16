// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitor for the shared AXI clock/reset (ACLK/ARESETn). AXI is a single-reset
// protocol, so one instance covers all five channels: it broadcasts an
// axi_reset_item on every reset state change.

class axi_reset_monitor extends uvm_monitor;
  `uvm_component_utils(axi_reset_monitor);

  // A port that broadcasts an item on every reset state change.
  uvm_analysis_port #(axi_reset_item) m_analysis_port;

  // The clock/reset interface being tracked. Set this with set_vif before run_phase.
  local virtual clk_rst_if m_vif;

  extern function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);

  extern function void set_vif(virtual clk_rst_if vif);
endclass

function void axi_reset_monitor::set_vif(virtual clk_rst_if vif);
  m_vif = vif;
endfunction

function axi_reset_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
  m_analysis_port = new("m_analysis_port", this);
endfunction

task axi_reset_monitor::run_phase(uvm_phase phase);
  if (m_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot monitor interface: vif is null.")
    return;
  end

  wait(!$isunknown(m_vif.rst_n));
  forever begin
    axi_reset_item rst_item;
    bit rst_n_bit = bit'(m_vif.rst_n);

    rst_item = axi_reset_item::type_id::create("rst_item");
    rst_item.m_in_reset = !rst_n_bit;
    m_analysis_port.write(rst_item);

    wait(m_vif.rst_n === !rst_n_bit);
  end
endtask
