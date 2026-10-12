// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// AXI agent that observes an axi_if: the monitor, the reset monitor and the register adapter, with
// the monitor's analysis ports. axi_mgr_agent extends it to drive the bus when the interface is in
// Manager mode.

class axi_agent extends uvm_agent;
  `uvm_component_utils(axi_agent)

  // Analysis ports for requests, responses and complete transactions (see axi_monitor)
  uvm_analysis_port #(axi_mon_item) m_request_port;
  uvm_analysis_port #(axi_mon_item) m_response_port;
  uvm_analysis_port #(axi_mon_item) m_transaction_port;

  // Set the bus with set_vif() before build_phase or through uvm_config_db
  protected axi_vif_t m_vif;

  // Shared ACLK and ARESETn monitor
  protected axi_reset_monitor m_reset_monitor;

  protected axi_monitor m_monitor;

  // Stateless register adapter, available in every mode for a register predictor
  protected axi_reg_adapter m_reg_adapter;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

  // Class specific methods

  extern function void set_vif(axi_vif_t vif);

  // Call after build_phase
  extern function axi_vif_t get_vif();

  // Call after build_phase
  extern function axi_reg_adapter get_reg_adapter();

  // Call after build_phase
  extern function axi_reset_monitor get_reset_monitor();
  extern function axi_monitor get_monitor();

  // Return whether the agent drives a bus whose interface is in the given mode; in any other mode it
  // only observes the bus
  extern protected virtual function bit drives_in_mode(axi_if_mode_e mode);
endclass: axi_agent


function axi_agent::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction: new

function void axi_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  m_request_port     = new("m_request_port", this);
  m_response_port    = new("m_response_port", this);
  m_transaction_port = new("m_transaction_port", this);

  if (m_vif == null && !uvm_config_db#(axi_vif_t)::get(this, "", "vif", m_vif)) begin
    `uvm_fatal(get_full_name(), "failed to get vif from uvm_config_db")
  end
  if (m_vif == null) begin
    `uvm_fatal(get_full_name(), "No non-null m_vif provided.")
  end
  is_active = drives_in_mode(m_vif.if_mode) ? UVM_ACTIVE : UVM_PASSIVE;

  m_reset_monitor = axi_reset_monitor::type_id::create("m_reset_monitor", this);
  m_reset_monitor.set_vif(m_vif.u_clk_rst_if);

  m_monitor = axi_monitor::type_id::create("m_monitor", this);
  m_monitor.set_interfaces(m_vif.aw_if, m_vif.w_if, m_vif.b_if, m_vif.ar_if, m_vif.r_if,
                           m_vif.u_clk_rst_if);

  m_reg_adapter = axi_reg_adapter::type_id::create("m_reg_adapter");
  m_reg_adapter.set_bus_bytes(m_vif.w_if.data_width / 8);
endfunction: build_phase

function void axi_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  m_monitor.m_request_port.connect(m_request_port);
  m_monitor.m_response_port.connect(m_response_port);
  m_monitor.m_transaction_port.connect(m_transaction_port);
endfunction: connect_phase

function void axi_agent::set_vif(axi_vif_t vif);
  if (m_vif != null) begin
    `uvm_fatal(get_full_name(), "Cannot set vif: m_vif is already non-null.")
  end else if (vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot set vif to null.")
  end else begin
    m_vif = vif;
  end
endfunction: set_vif

function axi_vif_t axi_agent::get_vif();
  if (m_vif == null) begin
    `uvm_fatal(get_full_name(), "m_vif is null.")
  end
  return m_vif;
endfunction: get_vif

function axi_reg_adapter axi_agent::get_reg_adapter();
  if (m_reg_adapter == null) begin
    `uvm_fatal(get_full_name(), "m_reg_adapter is null.")
  end
  return m_reg_adapter;
endfunction: get_reg_adapter

function axi_reset_monitor axi_agent::get_reset_monitor();
  if (m_reset_monitor == null) begin
    `uvm_fatal(get_full_name(), "m_reset_monitor is null.")
  end
  return m_reset_monitor;
endfunction: get_reset_monitor

function axi_monitor axi_agent::get_monitor();
  if (m_monitor == null) begin
    `uvm_fatal(get_full_name(), "m_monitor is null.")
  end
  return m_monitor;
endfunction: get_monitor

function bit axi_agent::drives_in_mode(axi_if_mode_e mode);
  return 1'b0;
endfunction: drives_in_mode
