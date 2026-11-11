// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class mailbox_env extends uvm_env;
  `uvm_component_utils(mailbox_env)

  // Set by the test before build_phase
  mailbox_env_cfg cfg;

  axi_mgr_agent             m_axi_agent[NumPorts];
  mailbox_reg_predictor     m_predictor[NumPorts];
  mailbox_scoreboard        m_scoreboard;
  mailbox_virtual_sequencer m_vsqr;
  mailbox_env_cov           m_cov;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
endclass : mailbox_env


function mailbox_env::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void mailbox_env::build_phase(uvm_phase phase);
  if (cfg == null) begin
    `uvm_fatal(`gfn, "cfg is null")
  end

  foreach (m_axi_agent[i]) begin
    m_axi_agent[i] = axi_mgr_agent::type_id::create({"m_axi_agent_", PortName[i]}, this);
    m_predictor[i] = mailbox_reg_predictor::type_id::create({"m_predictor_", PortName[i]}, this);
  end

  if (cfg.en_cov) begin
    m_cov = mailbox_env_cov::type_id::create("m_cov", this);
  end

  m_scoreboard = mailbox_scoreboard::type_id::create("m_scoreboard", this);
  m_scoreboard.cfg = cfg;
  m_scoreboard.cov = m_cov;

  m_vsqr = mailbox_virtual_sequencer::type_id::create("m_vsqr", this);
  m_vsqr.cfg = cfg;
endfunction : build_phase

function void mailbox_env::connect_phase(uvm_phase phase);
  foreach (m_axi_agent[i]) begin
    uvm_reg_map map = cfg.ral[i].default_map;

    // Use monitor prediction to keep error responses out of the mirror
    map.set_sequencer(m_axi_agent[i].get_register_layering_sequencer(),
                      m_axi_agent[i].get_reg_adapter());
    map.set_auto_predict(0);
    m_predictor[i].map     = map;
    m_predictor[i].adapter = m_axi_agent[i].get_reg_adapter();
    m_axi_agent[i].m_transaction_port.connect(m_predictor[i].mon_imp);
  end

  // An access takes effect somewhere between its request handshake and its response, so the
  // scoreboard takes both ends of every access on each port
  m_axi_agent[PortMain].m_request_port.connect(m_scoreboard.main_req_imp);
  m_axi_agent[PortExt].m_request_port.connect(m_scoreboard.ext_req_imp);
  m_axi_agent[PortMain].m_transaction_port.connect(m_scoreboard.main_txn_imp);
  m_axi_agent[PortExt].m_transaction_port.connect(m_scoreboard.ext_txn_imp);
  // Both ports share one reset
  m_axi_agent[PortMain].get_reset_monitor().m_analysis_port.connect(m_scoreboard.reset_imp);
endfunction : connect_phase

task mailbox_env::run_phase(uvm_phase phase);
  foreach (m_axi_agent[i]) begin
    automatic int unsigned port = i;

    fork
      begin : register_layer
        m_axi_agent[port].run_layered_register_vseq();
      end : register_layer
    join_none
  end
endtask : run_phase
