// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// An AXI agent on the SRAM port feeds the scoreboard and the coverage model from its monitor.
// When active, it is a manager agent, and the virtual sequencer gives sequences its sequencers and
// the cfg.
class axi_sram_env extends uvm_env;
  `uvm_component_utils(axi_sram_env)

  // Set by the test before build_phase
  axi_sram_env_cfg cfg;

  axi_agent                  m_agent;
  axi_sram_scoreboard        m_scoreboard;
  axi_sram_virtual_sequencer m_vseqr;
  axi_sram_env_cov           m_cov;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
endclass : axi_sram_env


function axi_sram_env::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sram_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (cfg == null) begin
    `uvm_fatal(get_full_name(), "cfg is null")
  end

  if (cfg.is_active == UVM_ACTIVE) begin
    m_agent = axi_mgr_agent::type_id::create("m_agent", this);
    m_vseqr = axi_sram_virtual_sequencer::type_id::create("m_vseqr", this);
    m_vseqr.cfg = cfg;
  end else begin
    m_agent = axi_agent::type_id::create("m_agent", this);
  end
  m_agent.set_vif(cfg.axi_vif);

  if (cfg.en_scb) begin
    m_scoreboard = axi_sram_scoreboard::type_id::create("m_scoreboard", this);
    m_scoreboard.cfg = cfg;
  end

  if (cfg.en_cov) begin
    m_cov = axi_sram_env_cov::type_id::create("m_cov", this);
  end
endfunction : build_phase

function void axi_sram_env::connect_phase(uvm_phase phase);
  axi_mgr_agent mgr;

  super.connect_phase(phase);

  if (cfg.en_scb) begin
    m_agent.get_monitor().m_transaction_port.connect(m_scoreboard.tx_imp);
  end
  if (cfg.en_cov) begin
    m_agent.get_monitor().m_transaction_port.connect(m_cov.analysis_export);
  end

  if (cfg.is_active == UVM_ACTIVE) begin
    $cast(mgr, m_agent);
    m_vseqr.write_request_seqr    = mgr.get_write_request_sequencer();
    m_vseqr.write_data_seqr       = mgr.get_write_data_sequencer();
    m_vseqr.write_response_seqr   = mgr.get_write_response_sequencer();
    m_vseqr.read_request_seqr     = mgr.get_read_request_sequencer();
    m_vseqr.read_data_seqr        = mgr.get_read_data_sequencer();
    m_vseqr.write_response_router = mgr.get_write_response_router();
    m_vseqr.read_response_router  = mgr.get_read_response_router();
  end
endfunction : connect_phase
