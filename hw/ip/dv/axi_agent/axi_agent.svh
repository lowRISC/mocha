// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The AXI agent. When cfg.is_active it drives all five channels as a manager; when passive it
// builds only the monitors, which is how it is used to tap subordinate ports.

class axi_agent extends uvm_agent;
  `uvm_component_utils(axi_agent)

  typedef uvm_sequencer #(axi_reg_op_item) layered_reg_sequencer_t;

  // The agent config object, which allows the testbench to supply virtual interfaces. This can
  // either be set by calling set_cfg() before the build phase, or provided through uvm_config_db.
  local axi_agent_cfg m_cfg;

  // Reset monitor for the shared AXI clock/reset (covers all five channels).
  local axi_reset_monitor m_reset_monitor;

  // The write request channel (AW)
  local axi_mgr_write_request_driver m_write_request_driver;
  local write_request_sequencer_t    m_write_request_sequencer;

  // The write data channel (W)
  local axi_mgr_write_data_driver m_write_data_driver;
  local write_data_sequencer_t    m_write_data_sequencer;

  // The write response channel (B)
  local axi_mgr_write_response_driver m_write_response_driver;
  local write_response_sequencer_t    m_write_response_sequencer;

  // The read request channel (AR)
  local axi_mgr_read_request_driver m_read_request_driver;
  local read_request_sequencer_t    m_read_request_sequencer;

  // The read data channel (R)
  local axi_mgr_read_data_driver m_read_data_driver;
  local read_data_sequencer_t    m_read_data_sequencer;

  // A response router for writes
  local axi_response_router m_write_response_router;

  // A response router for reads
  local axi_response_router m_read_response_router;

  // A transaction monitor. Built whether the agent is active or passive.
  local axi_monitor m_monitor;

  // A reg adapter. This is stateless, so gets created in build_phase whenever the agent is active.
  // It's useful in conjunction with a layered sequencer (which is created by
  // run_layered_register_vseq and can be retrieved with get_register_layering_sequencer).
  local axi_reg_adapter m_reg_adapter;

  // A sequencer that controls access to an instance of axi_mgr_register_layer_vseq that is
  // currently running.
  local layered_reg_sequencer_t m_layered_reg_sequencer;

  extern function new (string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

  // Set m_cfg to the provided cfg.
  //
  // This can only run once, and must be run before the build phase. If it is not run, build_phase
  // will try to get the config object from uvm_config_db.
  extern function void set_cfg(axi_agent_cfg cfg);

  // Get the reset monitor for the shared AXI clock/reset. Can only be called after build_phase.
  extern function axi_reset_monitor get_reset_monitor();

  // Get the transaction monitor. Can only be called after build_phase.
  extern function axi_monitor get_monitor();

  // Get the sequencer for the write request channel (AW). Can only be called after build_phase, and
  // the agent must be active.
  extern function write_request_sequencer_t get_write_request_sequencer();

  // Get the sequencer for the write data channel (W). Can only be called after build_phase, and the
  // agent must be active.
  extern function write_data_sequencer_t get_write_data_sequencer();

  // Get the sequencer for the write response channel (B). Can only be called after build_phase, and
  // the agent must be active.
  extern function write_response_sequencer_t get_write_response_sequencer();

  // Get the sequencer for the read request channel (AR). Can only be called after build_phase, and
  // the agent must be active.
  extern function read_request_sequencer_t get_read_request_sequencer();

  // Get the sequencer for the read data channel (R). Can only be called after build_phase, and the
  // agent must be active.
  extern function read_data_sequencer_t get_read_data_sequencer();

  // Get the write response router. Can only be called after build_phase, and the
  // agent must be active.
  extern function axi_response_router get_write_response_router();

  // Get the read response router. Can only be called after build_phase, and the
  // agent must be active.
  extern function axi_response_router get_read_response_router();

  // Get the reg adapter. Can only be called after build_phase, and the agent must be active.
  extern function axi_reg_adapter get_layered_reg_adapter();

  // Run the layered register vseq, which shouldn't already be running.
  //
  // This sequence will run forever and its layering sequencer can be retrieved with
  // get_register_layering_sequencer().
  extern task run_layered_register_vseq();

  // Get a handle a the sequencer for a layered register vseq that is currently running. If there is
  // not yet one running, this returns null.
  extern function layered_reg_sequencer_t get_register_layering_sequencer();
endclass

function axi_agent::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction

function void axi_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (m_cfg == null && !uvm_config_db#(axi_agent_cfg)::get(this, "", "cfg", m_cfg)) begin
    `uvm_fatal(get_full_name(), "failed to get cfg object from uvm_config_db")
  end

  // One reset monitor for the shared AXI clock/reset (ACLK/ARESETn). As well as broadcasting reset
  // items, this is what maintains m_cfg.in_reset for the channel drivers.
  m_reset_monitor = axi_reset_monitor::type_id::create("m_reset_monitor", this);
  m_reset_monitor.set_cfg(m_cfg);

  // Passive transaction monitor: built in both active and passive agents.
  m_monitor = axi_monitor::type_id::create("m_monitor", this);
  m_monitor.set_cfg(m_cfg);

  if (m_cfg.is_active) begin
    // Create routers for write and read responses
    m_write_response_router = axi_response_router::type_id::create("m_write_response_router", this);
    m_read_response_router = axi_response_router::type_id::create("m_read_response_router", this);

    m_reg_adapter = axi_reg_adapter::type_id::create("m_reg_adapter");

    // Generate drivers and sequencers for the five channels.
    // The write request channel (AW)
    m_write_request_driver =
      axi_mgr_write_request_driver::type_id::create("m_write_request_driver", this);
    m_write_request_driver.cfg = m_cfg;
    m_write_request_sequencer =
      write_request_sequencer_t::type_id::create("m_write_request_sequencer", this);

    // The write data channel (W)
    m_write_data_driver = axi_mgr_write_data_driver::type_id::create("m_write_data_driver", this);
    m_write_data_driver.cfg = m_cfg;
    m_write_data_sequencer =
      write_data_sequencer_t::type_id::create("m_write_data_sequencer", this);

    // The write response channel (B)
    m_write_response_driver =
      axi_mgr_write_response_driver::type_id::create("m_write_response_driver", this);
    m_write_response_driver.cfg = m_cfg;
    m_write_response_sequencer =
      write_response_sequencer_t::type_id::create("m_write_response_sequencer", this);

    // The read request channel (AR)
    m_read_request_driver =
      axi_mgr_read_request_driver::type_id::create("m_read_request_driver", this);
    m_read_request_driver.cfg = m_cfg;
    m_read_request_sequencer =
      read_request_sequencer_t::type_id::create("m_read_request_sequencer", this);

    // The read data channel (R)
    m_read_data_driver = axi_mgr_read_data_driver::type_id::create("m_read_data_driver", this);
    m_read_data_driver.cfg = m_cfg;
    m_read_data_sequencer = read_data_sequencer_t::type_id::create("m_read_data_sequencer", this);
  end
endfunction

function void axi_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  // If the agent is active, connect drivers to sequencers.
  if (m_cfg.is_active) begin
    m_write_request_driver.seq_item_port.connect(m_write_request_sequencer.seq_item_export);
    m_write_data_driver.seq_item_port.connect(m_write_data_sequencer.seq_item_export);
    m_write_response_driver.seq_item_port.connect(m_write_response_sequencer.seq_item_export);
    m_read_request_driver.seq_item_port.connect(m_read_request_sequencer.seq_item_export);
    m_read_data_driver.seq_item_port.connect(m_read_data_sequencer.seq_item_export);

    // Both response routers observe the same shared reset.
    m_reset_monitor.m_analysis_port.connect(m_write_response_router.reset_imp);
    m_reset_monitor.m_analysis_port.connect(m_read_response_router.reset_imp);
  end
endfunction

function void axi_agent::set_cfg(axi_agent_cfg cfg);
  if (m_cfg != null) `uvm_fatal(get_full_name(), "Cannot set cfg: m_cfg is already non-null.")
  m_cfg = cfg;
endfunction

function axi_reset_monitor axi_agent::get_reset_monitor();
  if (m_reset_monitor == null) `uvm_fatal(get_full_name(), "m_reset_monitor is null.")
  return m_reset_monitor;
endfunction

function axi_monitor axi_agent::get_monitor();
  if (m_monitor == null) `uvm_fatal(get_full_name(), "m_monitor is null.")
  return m_monitor;
endfunction

function write_request_sequencer_t axi_agent::get_write_request_sequencer();
  if (m_write_request_sequencer == null)
    `uvm_fatal(get_full_name(), "m_write_request_sequencer is null.")
  return m_write_request_sequencer;
endfunction

function write_data_sequencer_t axi_agent::get_write_data_sequencer();
  if (m_write_data_sequencer == null)
    `uvm_fatal(get_full_name(), "m_write_data_sequencer is null.")
  return m_write_data_sequencer;
endfunction

function write_response_sequencer_t axi_agent::get_write_response_sequencer();
  if (m_write_response_sequencer == null)
    `uvm_fatal(get_full_name(), "m_write_response_sequencer is null.")
  return m_write_response_sequencer;
endfunction

function read_request_sequencer_t axi_agent::get_read_request_sequencer();
  if (m_read_request_sequencer == null)
    `uvm_fatal(get_full_name(), "m_read_request_sequencer is null.")
  return m_read_request_sequencer;
endfunction

function read_data_sequencer_t axi_agent::get_read_data_sequencer();
  if (m_read_data_sequencer == null)
    `uvm_fatal(get_full_name(), "m_read_data_sequencer is null.")
  return m_read_data_sequencer;
endfunction

function axi_response_router axi_agent::get_write_response_router();
  if (m_write_response_router == null)
    `uvm_fatal(get_full_name(), "m_write_response_router is null.")
  return m_write_response_router;
endfunction

function axi_response_router axi_agent::get_read_response_router();
  if (m_read_response_router == null)
    `uvm_fatal(get_full_name(), "m_read_response_router is null.")
  return m_read_response_router;
endfunction

function axi_reg_adapter axi_agent::get_layered_reg_adapter();
  if (m_reg_adapter == null) `uvm_fatal(get_full_name(), "m_reg_adapter is null.")
  return m_reg_adapter;
endfunction

task axi_agent::run_layered_register_vseq();
  axi_mgr_register_layer_vseq layer_vseq;

  if (m_layered_reg_sequencer != null) begin
    `uvm_fatal(get_full_name(), "Overlapping runs of layered register vseq.")
  end

  m_layered_reg_sequencer =
    layered_reg_sequencer_t::type_id::create("m_layered_reg_sequencer", this);

  layer_vseq = axi_mgr_register_layer_vseq::type_id::create("layer_vseq");

  layer_vseq.set_sequencers(m_layered_reg_sequencer,
                            m_write_request_sequencer,
                            m_write_data_sequencer,
                            m_write_response_sequencer,
                            m_read_request_sequencer,
                            m_read_data_sequencer);
  layer_vseq.set_response_routers(m_read_response_router, m_write_response_router);

  layer_vseq.start(null);

  // Because layer_vseq never completes, we don't expect to get her.
  `uvm_fatal(get_full_name(), "Instance of axi_mgr_register_layer_vseq ran to completion.")
endtask

function axi_agent::layered_reg_sequencer_t axi_agent::get_register_layering_sequencer();
  return m_layered_reg_sequencer;
endfunction
