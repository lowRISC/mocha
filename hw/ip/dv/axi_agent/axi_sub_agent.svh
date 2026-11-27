// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// AXI Subordinate agent: axi_agent plus a memory-backed driver per channel, built when the
// interface is in Subordinate mode. In any other mode it builds only what axi_agent builds.

class axi_sub_agent extends axi_agent;
  `uvm_component_utils(axi_sub_agent)

  // Publish accepted requests and response policies for scoreboard prediction (see
  // axi_sub_txn::get_accept_record). Passive mode publishes nothing.
  uvm_analysis_port #(axi_sub_txn) m_accept_port;

  // Creates a default configuration if none is provided
  local axi_sub_agent_cfg m_cfg;

  // Channel drivers and shared state
  local axi_sub_state                 m_state;
  local axi_sub_write_request_driver  m_write_request_driver;
  local axi_sub_write_data_driver     m_write_data_driver;
  local axi_sub_write_response_driver m_write_response_driver;
  local axi_sub_read_request_driver   m_read_request_driver;
  local axi_sub_read_data_driver      m_read_data_driver;

  // Distribute one response policy item per transaction from m_sequencer
  local axi_sub_policy_driver m_policy_driver;

  local axi_sub_rsp_sequencer_t m_sequencer;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

  // Class specific methods

  extern function void set_cfg(axi_sub_agent_cfg cfg);

  // Call after build_phase
  extern function axi_sub_agent_cfg get_cfg();

  // Call after build_phase
  extern function axi_mem_model_t get_mem();

  // Requires an active agent after build_phase
  extern function axi_sub_rsp_sequencer_t get_sequencer();

  extern protected virtual function bit drives_in_mode(axi_if_mode_e mode);
endclass : axi_sub_agent


function axi_sub_agent::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sub_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  m_accept_port = new("m_accept_port", this);

  if (m_cfg == null && !uvm_config_db#(axi_sub_agent_cfg)::get(this, "", "cfg", m_cfg)) begin
    m_cfg = axi_sub_agent_cfg::type_id::create("m_cfg");
  end
  if (m_cfg == null) begin
    `uvm_fatal(get_full_name(), "No non-null m_cfg provided.")
  end
  if (m_cfg.m_mem == null) begin
    m_cfg.m_mem = axi_mem_model_t::type_id::create("m_mem");
  end

  // The base adapter reports OKAY exclusive writes as failed when the subordinate supports them
  m_reg_adapter.set_exclusive_support(m_cfg.m_exclusive_support);

  if (get_is_active() == UVM_ACTIVE) begin
    m_cfg.check_settings(m_vif.is_lite, m_vif.w_if.data_width);

    m_state = axi_sub_state::type_id::create("m_state");
    m_state.set_cfg(m_cfg);
    m_state.set_bus(m_vif.is_lite, m_vif.w_if.data_width / 8);

    m_policy_driver = axi_sub_policy_driver::type_id::create("m_policy_driver", this);
    m_sequencer     = axi_sub_rsp_sequencer_t::type_id::create("m_sequencer", this);

    m_write_request_driver =
      axi_sub_write_request_driver::type_id::create("m_write_request_driver", this);
    m_write_data_driver = axi_sub_write_data_driver::type_id::create("m_write_data_driver", this);
    m_write_response_driver =
      axi_sub_write_response_driver::type_id::create("m_write_response_driver", this);
    m_read_request_driver =
      axi_sub_read_request_driver::type_id::create("m_read_request_driver", this);
    m_read_data_driver = axi_sub_read_data_driver::type_id::create("m_read_data_driver", this);
  end
endfunction : build_phase

function void axi_sub_agent::connect_phase(uvm_phase phase);
  axi_sub_driver_base drivers[5];

  super.connect_phase(phase);

  if (get_is_active() == UVM_ACTIVE) begin
    m_policy_driver.set_cfg(m_cfg);
    m_policy_driver.seq_item_port.connect(m_sequencer.seq_item_export);

    m_write_request_driver.set_vif(m_vif.aw_if, m_policy_driver);
    m_write_data_driver.set_vif(m_vif.w_if);
    m_write_response_driver.set_vif(m_vif.b_if);
    m_read_request_driver.set_vif(m_vif.ar_if, m_policy_driver);
    m_read_data_driver.set_vif(m_vif.r_if);
    m_write_request_driver.m_accept_port.connect(m_accept_port);
    m_read_request_driver.m_accept_port.connect(m_accept_port);

    drivers = '{m_write_request_driver, m_write_data_driver, m_write_response_driver,
                m_read_request_driver, m_read_data_driver};
    foreach (drivers[i]) begin
      drivers[i].set_cfg(m_cfg, m_state);
      drivers[i].set_clk_rst_vif(m_vif.u_clk_rst_if);
      drivers[i].set_drive_x_when_idle(m_vif.drive_x_when_idle);
    end
  end
endfunction : connect_phase

function void axi_sub_agent::set_cfg(axi_sub_agent_cfg cfg);
  if (m_cfg != null) begin
    `uvm_fatal(get_full_name(), "Cannot set cfg: m_cfg is already non-null.")
  end else if (cfg == null) begin
    `uvm_fatal(get_full_name(), "Cannot set cfg to null.")
  end else begin
    m_cfg = cfg;
  end
endfunction : set_cfg

function axi_sub_agent_cfg axi_sub_agent::get_cfg();
  if (m_cfg == null) begin
    `uvm_fatal(get_full_name(), "m_cfg is null.")
  end
  return m_cfg;
endfunction : get_cfg

function axi_mem_model_t axi_sub_agent::get_mem();
  return get_cfg().m_mem;
endfunction : get_mem

function axi_sub_rsp_sequencer_t axi_sub_agent::get_sequencer();
  if (m_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_sequencer is null.")
  end
  return m_sequencer;
endfunction : get_sequencer

function bit axi_sub_agent::drives_in_mode(axi_if_mode_e mode);
  return mode == Subordinate;
endfunction : drives_in_mode
