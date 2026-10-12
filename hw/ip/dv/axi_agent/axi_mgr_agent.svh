// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Active AXI Manager agent with a driver and sequencer per channel. Passive mode builds only the
// monitor, the reset monitor and the register adapter, to observe an RTL-driven bus.

class axi_mgr_agent extends uvm_agent;
  `uvm_component_utils(axi_mgr_agent)

  typedef uvm_sequencer #(axi_reg_op_item) layered_reg_sequencer_t;

  // Analysis ports for requests, responses and complete transactions (see axi_monitor)
  uvm_analysis_port #(axi_mon_item) m_request_port;
  uvm_analysis_port #(axi_mon_item) m_response_port;
  uvm_analysis_port #(axi_mon_item) m_transaction_port;

  // Set the bus with set_vif() before build_phase or through uvm_config_db
  local axi_vif_t m_vif;

  // Shared ACLK and ARESETn monitor
  local axi_reset_monitor m_reset_monitor;

  local axi_monitor m_monitor;

  local axi_mgr_write_request_driver  m_write_request_driver;
  local write_request_sequencer_t     m_write_request_sequencer;
  local axi_mgr_write_data_driver     m_write_data_driver;
  local write_data_sequencer_t        m_write_data_sequencer;
  local axi_mgr_write_response_driver m_write_response_driver;
  local write_response_sequencer_t    m_write_response_sequencer;
  local axi_mgr_read_request_driver   m_read_request_driver;
  local read_request_sequencer_t      m_read_request_sequencer;
  local axi_mgr_read_data_driver      m_read_data_driver;
  local read_data_sequencer_t         m_read_data_sequencer;

  // Route B responses and R beats to sequences waiting on their IDs
  local axi_response_router m_write_response_router;
  local axi_response_router m_read_response_router;

  // Transfer sequencer with access to the channel sequencers and response routers
  local axi_txn_sequencer_t m_sequencer;

  // Stateless register adapter, also available in passive mode for a register predictor
  local axi_reg_adapter m_reg_adapter;

  // Controls access to axi_mgr_register_layer_vseq. Create in build_phase when active; UVM forbids
  // creating components later.
  local layered_reg_sequencer_t m_layered_reg_sequencer;

  // Set once run_layered_register_vseq has started the layered register vseq
  local bit m_layer_vseq_running;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

  // Class specific methods

  extern function void set_vif(axi_vif_t vif);

  // Call after build_phase
  extern function axi_vif_t get_vif();

  // For axi_transfer_seq; requires an active agent after build_phase
  extern function axi_txn_sequencer_t get_sequencer();

  // Call after build_phase
  extern function axi_reg_adapter get_reg_adapter();

  // Call after build_phase
  extern function axi_reset_monitor get_reset_monitor();
  extern function axi_monitor get_monitor();

  // Requires an active agent after build_phase
  extern function write_request_sequencer_t get_write_request_sequencer();
  extern function write_data_sequencer_t get_write_data_sequencer();
  extern function write_response_sequencer_t get_write_response_sequencer();
  extern function read_request_sequencer_t get_read_request_sequencer();
  extern function read_data_sequencer_t get_read_data_sequencer();

  // Requires an active agent after build_phase
  extern function axi_response_router get_write_response_router();
  extern function axi_response_router get_read_response_router();

  // Start the layered register sequence once. It runs forever; get_register_layering_sequencer()
  // provides access. Optional arguments fix AxPROT for integrations that require it.
  extern task run_layered_register_vseq(bit                    has_fixed_prot = 1'b0,
                                        bit [AxiProtWidth-1:0] fixed_prot = '0);

  // Access the layered register sequence if started; requires an active agent after build_phase
  extern function layered_reg_sequencer_t get_register_layering_sequencer();
endclass: axi_mgr_agent


function axi_mgr_agent::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction: new

function void axi_mgr_agent::build_phase(uvm_phase phase);
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

  m_reset_monitor = axi_reset_monitor::type_id::create("m_reset_monitor", this);
  m_reset_monitor.set_vif(m_vif.u_clk_rst_if);

  m_monitor = axi_monitor::type_id::create("m_monitor", this);
  m_monitor.set_interfaces(m_vif.aw_if, m_vif.w_if, m_vif.b_if, m_vif.ar_if, m_vif.r_if,
                           m_vif.u_clk_rst_if);

  m_reg_adapter = axi_reg_adapter::type_id::create("m_reg_adapter");
  m_reg_adapter.set_bus_bytes(m_vif.w_if.data_width / 8);

  if (get_is_active() == UVM_ACTIVE) begin
    // AXI4-Lite data width must be 32 or 64 bits (AMBA AXI H.c B1.1.2)
    if (m_vif.is_lite && !(m_vif.w_if.data_width inside {32, 64})) begin
      `uvm_error(get_full_name(),
                 $sformatf("AXI4-Lite needs a 32 or 64 bit data bus, not %0d bits.",
                           m_vif.w_if.data_width))
    end

    m_write_response_router = axi_response_router::type_id::create("m_write_response_router",
                                                                   this);
    m_read_response_router = axi_response_router::type_id::create("m_read_response_router", this);

    m_sequencer = axi_txn_sequencer_t::type_id::create("m_sequencer", this);
    m_layered_reg_sequencer = layered_reg_sequencer_t::type_id::create("m_layered_reg_sequencer",
                                                                       this);

    m_write_request_driver =
      axi_mgr_write_request_driver::type_id::create("m_write_request_driver", this);
    m_write_request_driver.set_vif(m_vif.aw_if);
    m_write_request_driver.set_clk_rst_vif(m_vif.u_clk_rst_if);
    m_write_request_driver.set_drive_x_when_idle(m_vif.drive_x_when_idle);
    m_write_request_driver.set_lite(m_vif.is_lite, m_vif.w_if.data_width);
    m_write_request_sequencer =
      write_request_sequencer_t::type_id::create("m_write_request_sequencer", this);

    m_write_data_driver = axi_mgr_write_data_driver::type_id::create("m_write_data_driver", this);
    m_write_data_driver.set_vif(m_vif.w_if);
    m_write_data_driver.set_clk_rst_vif(m_vif.u_clk_rst_if);
    m_write_data_driver.set_drive_x_when_idle(m_vif.drive_x_when_idle);
    m_write_data_driver.set_lite(m_vif.is_lite);
    m_write_data_sequencer =
      write_data_sequencer_t::type_id::create("m_write_data_sequencer", this);

    m_write_response_driver =
      axi_mgr_write_response_driver::type_id::create("m_write_response_driver", this);
    m_write_response_driver.set_vif(m_vif.b_if);
    m_write_response_driver.set_clk_rst_vif(m_vif.u_clk_rst_if);
    m_write_response_sequencer =
      write_response_sequencer_t::type_id::create("m_write_response_sequencer", this);

    m_read_request_driver =
      axi_mgr_read_request_driver::type_id::create("m_read_request_driver", this);
    m_read_request_driver.set_vif(m_vif.ar_if);
    m_read_request_driver.set_clk_rst_vif(m_vif.u_clk_rst_if);
    m_read_request_driver.set_drive_x_when_idle(m_vif.drive_x_when_idle);
    m_read_request_driver.set_lite(m_vif.is_lite, m_vif.r_if.data_width);
    m_read_request_sequencer =
      read_request_sequencer_t::type_id::create("m_read_request_sequencer", this);

    m_read_data_driver = axi_mgr_read_data_driver::type_id::create("m_read_data_driver", this);
    m_read_data_driver.set_vif(m_vif.r_if);
    m_read_data_driver.set_clk_rst_vif(m_vif.u_clk_rst_if);
    m_read_data_sequencer = read_data_sequencer_t::type_id::create("m_read_data_sequencer", this);
  end
endfunction: build_phase

function void axi_mgr_agent::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  m_monitor.m_request_port.connect(m_request_port);
  m_monitor.m_response_port.connect(m_response_port);
  m_monitor.m_transaction_port.connect(m_transaction_port);

  if (get_is_active() == UVM_ACTIVE) begin
    m_write_request_driver.seq_item_port.connect(m_write_request_sequencer.seq_item_export);
    m_write_data_driver.seq_item_port.connect(m_write_data_sequencer.seq_item_export);
    m_write_response_driver.seq_item_port.connect(m_write_response_sequencer.seq_item_export);
    m_read_request_driver.seq_item_port.connect(m_read_request_sequencer.seq_item_export);
    m_read_data_driver.seq_item_port.connect(m_read_data_sequencer.seq_item_export);

    m_reset_monitor.m_analysis_port.connect(m_write_response_router.reset_imp);
    m_reset_monitor.m_analysis_port.connect(m_read_response_router.reset_imp);

    m_sequencer.m_write_request_sequencer  = m_write_request_sequencer;
    m_sequencer.m_write_data_sequencer     = m_write_data_sequencer;
    m_sequencer.m_write_response_sequencer = m_write_response_sequencer;
    m_sequencer.m_read_request_sequencer   = m_read_request_sequencer;
    m_sequencer.m_read_data_sequencer      = m_read_data_sequencer;
    m_sequencer.m_write_response_router    = m_write_response_router;
    m_sequencer.m_read_response_router     = m_read_response_router;
    m_sequencer.m_vif                      = m_vif;
  end
endfunction: connect_phase

function void axi_mgr_agent::set_vif(axi_vif_t vif);
  if (m_vif != null) begin
    `uvm_fatal(get_full_name(), "Cannot set vif: m_vif is already non-null.")
  end else if (vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot set vif to null.")
  end else begin
    m_vif = vif;
  end
endfunction: set_vif

function axi_vif_t axi_mgr_agent::get_vif();
  if (m_vif == null) begin
    `uvm_fatal(get_full_name(), "m_vif is null.")
  end
  return m_vif;
endfunction: get_vif

function axi_txn_sequencer_t axi_mgr_agent::get_sequencer();
  if (m_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_sequencer is null.")
  end
  return m_sequencer;
endfunction: get_sequencer

function axi_reg_adapter axi_mgr_agent::get_reg_adapter();
  if (m_reg_adapter == null) begin
    `uvm_fatal(get_full_name(), "m_reg_adapter is null.")
  end
  return m_reg_adapter;
endfunction: get_reg_adapter

function axi_reset_monitor axi_mgr_agent::get_reset_monitor();
  if (m_reset_monitor == null) begin
    `uvm_fatal(get_full_name(), "m_reset_monitor is null.")
  end
  return m_reset_monitor;
endfunction: get_reset_monitor

function axi_monitor axi_mgr_agent::get_monitor();
  if (m_monitor == null) begin
    `uvm_fatal(get_full_name(), "m_monitor is null.")
  end
  return m_monitor;
endfunction: get_monitor

function write_request_sequencer_t axi_mgr_agent::get_write_request_sequencer();
  if (m_write_request_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_write_request_sequencer is null.")
  end
  return m_write_request_sequencer;
endfunction: get_write_request_sequencer

function write_data_sequencer_t axi_mgr_agent::get_write_data_sequencer();
  if (m_write_data_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_write_data_sequencer is null.")
  end
  return m_write_data_sequencer;
endfunction: get_write_data_sequencer

function write_response_sequencer_t axi_mgr_agent::get_write_response_sequencer();
  if (m_write_response_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_write_response_sequencer is null.")
  end
  return m_write_response_sequencer;
endfunction: get_write_response_sequencer

function read_request_sequencer_t axi_mgr_agent::get_read_request_sequencer();
  if (m_read_request_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_read_request_sequencer is null.")
  end
  return m_read_request_sequencer;
endfunction: get_read_request_sequencer

function read_data_sequencer_t axi_mgr_agent::get_read_data_sequencer();
  if (m_read_data_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_read_data_sequencer is null.")
  end
  return m_read_data_sequencer;
endfunction: get_read_data_sequencer

function axi_response_router axi_mgr_agent::get_write_response_router();
  if (m_write_response_router == null) begin
    `uvm_fatal(get_full_name(), "m_write_response_router is null.")
  end
  return m_write_response_router;
endfunction: get_write_response_router

function axi_response_router axi_mgr_agent::get_read_response_router();
  if (m_read_response_router == null) begin
    `uvm_fatal(get_full_name(), "m_read_response_router is null.")
  end
  return m_read_response_router;
endfunction: get_read_response_router

task axi_mgr_agent::run_layered_register_vseq(bit                    has_fixed_prot = 1'b0,
                                              bit [AxiProtWidth-1:0] fixed_prot = '0);
  axi_mgr_register_layer_vseq layer_vseq;

  if (m_layer_vseq_running) begin
    `uvm_fatal(get_full_name(), "Layered vseq already running.")
  end
  m_layer_vseq_running = 1'b1;

  layer_vseq = axi_mgr_register_layer_vseq::type_id::create("layer_vseq");

  layer_vseq.set_sequencers(m_layered_reg_sequencer,
                            m_write_request_sequencer,
                            m_write_data_sequencer,
                            m_write_response_sequencer,
                            m_read_request_sequencer,
                            m_read_data_sequencer);
  layer_vseq.set_response_routers(m_read_response_router, m_write_response_router);

  layer_vseq.set_bus_properties(.data_width     (m_vif.w_if.data_width),
                                .id_w_width     (m_vif.aw_if.id_w_width),
                                .id_r_width     (m_vif.ar_if.id_r_width),
                                .awuser_width   (m_vif.aw_if.user_req_width),
                                .aruser_width   (m_vif.ar_if.user_req_width),
                                .user_data_width(m_vif.w_if.user_data_width));

  // A fixed AxPROT is an environment-specific restriction
  layer_vseq.set_lite(m_vif.is_lite);
  layer_vseq.set_fixed_prot(has_fixed_prot, fixed_prot);

  layer_vseq.start(null);

  // layer_vseq runs forever
  `uvm_fatal(get_full_name(), "Instance of axi_mgr_register_layer_vseq ran to completion.")
endtask: run_layered_register_vseq

function axi_mgr_agent::layered_reg_sequencer_t axi_mgr_agent::get_register_layering_sequencer();
  if (m_layered_reg_sequencer == null) begin
    `uvm_fatal(get_full_name(), "m_layered_reg_sequencer is null.")
  end
  return m_layered_reg_sequencer;
endfunction: get_register_layering_sequencer
