// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// AXI agent self-test environment with an agent at each link endpoint. Agents observing pulp_axi
// models are passive. On the agent link, tb.sv cross-wires two axi_if instances because one
// interface can drive only one role.

class axi_agent_env extends dv_base_env #(
    .CFG_T               (axi_agent_env_cfg),
    .VIRTUAL_SEQUENCER_T (axi_agent_virtual_sequencer),
    .SCOREBOARD_T        (axi_agent_scoreboard),
    .COV_T               (axi_agent_env_cov)
  );
  `uvm_component_utils(axi_agent_env)

  axi_mgr_agent m_mgr_agents[];
  axi_sub_agent m_sub_agents[];

  // First endpoints (all links except the crossbar have one of each)
  axi_mgr_agent m_mgr_agent;
  axi_sub_agent m_sub_agent;

  // Optional predictor from the first manager's monitor, filtering failed transactions
  // (cfg.m_reg_predictor)
  uvm_reg_predictor #(uvm_sequence_item) m_reg_predictor;
  axi_agent_reg_ok_filter                m_reg_filter;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass : axi_agent_env


function axi_agent_env::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_agent_env::build_phase(uvm_phase phase);
  axi_vif_t                  mgr_vifs[];
  axi_vif_t                  sub_vifs[];
  virtual axi_agent_probe_if bus_probe_vif;

  super.build_phase(phase);

  mgr_vifs = new[cfg.m_link.m_num_mgrs];
  sub_vifs = new[cfg.m_link.m_num_subs];
  foreach (mgr_vifs[i]) begin
    if (!uvm_config_db#(axi_vif_t)::get(this, "", $sformatf("mgr_vif_%0d", i), mgr_vifs[i])) begin
      `uvm_fatal(get_full_name(), $sformatf("Failed to get mgr_vif_%0d from uvm_config_db", i))
    end
  end
  foreach (sub_vifs[i]) begin
    if (!uvm_config_db#(axi_vif_t)::get(this, "", $sformatf("sub_vif_%0d", i), sub_vifs[i])) begin
      `uvm_fatal(get_full_name(), $sformatf("Failed to get sub_vif_%0d from uvm_config_db", i))
    end
  end
  if (!uvm_config_db#(virtual axi_agent_probe_if)::get(this, "", "probe_vif",
                                                       cfg.m_probe_vif)) begin
    `uvm_fatal(get_full_name(), "Failed to get probe_vif from uvm_config_db")
  end
  // tb.sv publishes a probe for every bus of the link, numbered from 0
  while (uvm_config_db#(virtual axi_agent_probe_if)::get(this, "",
             $sformatf("bus_probe_vif_%0d", cfg.m_bus_probe_vifs.size()), bus_probe_vif)) begin
    cfg.m_bus_probe_vifs.push_back(bus_probe_vif);
  end
  if (cfg.m_bus_probe_vifs.size() == 0) begin
    `uvm_fatal(get_full_name(), "Failed to get bus_probe_vif_0 from uvm_config_db")
  end
  void'(uvm_config_db#(virtual axi_agent_pulp_ctrl_if)::get(this, "", "pulp_ctrl_vif",
                                                            cfg.m_pulp_ctrl_vif));

  // tb.sv configures interfaces before UVM build
  cfg.m_addr_width  = mgr_vifs[0].aw_if.addr_width;
  cfg.m_data_width  = mgr_vifs[0].w_if.data_width;
  cfg.m_id_width    = mgr_vifs[0].aw_if.id_w_width;
  if (mgr_vifs[0].ar_if.id_r_width < cfg.m_id_width) begin
    cfg.m_id_width = mgr_vifs[0].ar_if.id_r_width;
  end
  cfg.m_user_width  = mgr_vifs[0].aw_if.user_req_width;
  if (mgr_vifs[0].ar_if.user_req_width < cfg.m_user_width) begin
    cfg.m_user_width = mgr_vifs[0].ar_if.user_req_width;
  end
  cfg.m_awuser_width = mgr_vifs[0].aw_if.user_req_width;
  cfg.m_aruser_width = mgr_vifs[0].ar_if.user_req_width;
  cfg.m_wuser_width  = mgr_vifs[0].w_if.user_data_width;
  cfg.m_buser_width  = mgr_vifs[0].b_if.user_resp_width;
  cfg.m_ruser_width  = mgr_vifs[0].r_if.user_data_width + mgr_vifs[0].r_if.user_resp_width;
  cfg.m_is_lite      = mgr_vifs[0].is_lite;
  cfg.m_sub_id_width    = sub_vifs[0].aw_if.id_w_width;
  cfg.m_sub_buser_width = sub_vifs[0].b_if.user_resp_width;
  cfg.m_sub_ruser_width = sub_vifs[0].r_if.user_data_width + sub_vifs[0].r_if.user_resp_width;
  cfg.m_sub_is_lite     = sub_vifs[0].is_lite;

  // Fit the traffic window to the address width
  if (mgr_vifs[0].aw_if.addr_width < 32) begin
    bit [AxiMaxAddrWidth-1:0] space = AxiMaxAddrWidth'(1) << mgr_vifs[0].aw_if.addr_width;

    cfg.m_link.m_addr_lo = 0;
    cfg.m_link.m_addr_hi = ((space < AxiWinBytes) ? space : AxiWinBytes) - 1;
  end

  if (cfg.m_link.m_kind == axi_agent_link_cfg::LinkSameBus &&
      (sub_vifs[0].w_if.data_width !== mgr_vifs[0].w_if.data_width ||
       sub_vifs[0].aw_if.id_w_width !== mgr_vifs[0].aw_if.id_w_width ||
       sub_vifs[0].ar_if.id_r_width !== mgr_vifs[0].ar_if.id_r_width ||
       sub_vifs[0].aw_if.addr_width !== mgr_vifs[0].aw_if.addr_width ||
       sub_vifs[0].is_lite !== mgr_vifs[0].is_lite)) begin
    `uvm_fatal(get_full_name(), "The two interfaces describe different buses.")
  end

  // Agents copy the interface's idle policy during build
  m_mgr_agents = new[cfg.m_link.m_num_mgrs];
  foreach (m_mgr_agents[i]) begin
    string name = $sformatf("m_mgr_agents[%0d]", i);

    if (cfg.m_link.m_mgr_is_agent) begin
      mgr_vifs[i].set_drive_x_when_idle(cfg.m_drive_x_when_idle);
    end
    m_mgr_agents[i] = axi_mgr_agent::type_id::create(name, this);
    m_mgr_agents[i].set_vif(mgr_vifs[i]);
  end
  m_sub_agents = new[cfg.m_link.m_num_subs];
  foreach (m_sub_agents[i]) begin
    string name = $sformatf("m_sub_agents[%0d]", i);

    if (cfg.m_link.m_sub_is_agent) begin
      sub_vifs[i].set_drive_x_when_idle(cfg.m_drive_x_when_idle);
    end
    m_sub_agents[i] = axi_sub_agent::type_id::create(name, this);
    m_sub_agents[i].set_vif(sub_vifs[i]);
    m_sub_agents[i].set_cfg(cfg.m_sub_agent_cfgs[i]);
  end
  m_mgr_agent = m_mgr_agents[0];
  m_sub_agent = m_sub_agents[0];

  if (cfg.m_reg_predictor) begin
    m_reg_predictor = uvm_reg_predictor#(uvm_sequence_item)::type_id::create("m_reg_predictor",
                                                                             this);
    m_reg_filter    = axi_agent_reg_ok_filter::type_id::create("m_reg_filter", this);
  end
endfunction : build_phase

function void axi_agent_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  foreach (m_mgr_agents[i]) begin
    m_mgr_agents[i].m_request_port.connect(scoreboard.m_mgr_request_fifos[i].analysis_export);
    m_mgr_agents[i].m_transaction_port.connect(scoreboard.m_mgr_txn_fifos[i].analysis_export);
  end
  foreach (m_sub_agents[i]) begin
    m_sub_agents[i].m_request_port.connect(scoreboard.m_sub_request_fifos[i].analysis_export);
    m_sub_agents[i].m_transaction_port.connect(scoreboard.m_sub_txn_fifos[i].analysis_export);
    m_sub_agents[i].m_accept_port.connect(scoreboard.m_sub_accept_fifos[i].analysis_export);
  end

  if (cfg.is_active) begin
    virtual_sequencer.m_mgr_agents     = m_mgr_agents;
    virtual_sequencer.m_sub_agents     = m_sub_agents;
    virtual_sequencer.m_mgr_agent      = m_mgr_agent;
    virtual_sequencer.m_sub_agent      = m_sub_agent;
    virtual_sequencer.m_mgr_sequencers = new[m_mgr_agents.size()];
    virtual_sequencer.m_sub_sequencers = new[m_sub_agents.size()];
    if (cfg.m_link.m_mgr_is_agent) begin
      foreach (m_mgr_agents[i]) begin
        virtual_sequencer.m_mgr_sequencers[i] = m_mgr_agents[i].get_sequencer();
      end
      virtual_sequencer.m_mgr_sequencer = virtual_sequencer.m_mgr_sequencers[0];
    end
    if (cfg.m_link.m_sub_is_agent) begin
      foreach (m_sub_agents[i]) begin
        virtual_sequencer.m_sub_sequencers[i] = m_sub_agents[i].get_sequencer();
      end
      virtual_sequencer.m_sub_sequencer = virtual_sequencer.m_sub_sequencers[0];
    end
    virtual_sequencer.m_mgr_driver_txn_port.connect(
        scoreboard.m_mgr_driver_txn_fifo.analysis_export);
  end

  if (m_reg_predictor != null) begin
    m_reg_filter.m_adapter    = m_mgr_agent.get_reg_adapter();
    m_reg_predictor.adapter   = m_mgr_agent.get_reg_adapter();
    m_mgr_agent.m_transaction_port.connect(m_reg_filter.analysis_export);
    m_reg_filter.m_out_port.connect(m_reg_predictor.bus_in);
    virtual_sequencer.m_reg_predictor = m_reg_predictor;
    virtual_sequencer.m_reg_filter    = m_reg_filter;
  end
endfunction : connect_phase
