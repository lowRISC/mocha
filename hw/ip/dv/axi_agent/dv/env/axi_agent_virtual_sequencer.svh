// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Virtual sequencer for the AXI agent self-test

class axi_agent_virtual_sequencer extends dv_base_virtual_sequencer #(
    .CFG_T(axi_agent_env_cfg),
    .COV_T(axi_agent_env_cov)
  );
  `uvm_component_utils(axi_agent_virtual_sequencer)

  // Agents at each endpoint, also providing channel and register-layer access. m_mgr_agent and
  // m_sub_agent are the first, and only the crossbar has more than one of each.
  axi_mgr_agent m_mgr_agents[];
  axi_sub_agent m_sub_agents[];
  axi_mgr_agent m_mgr_agent;
  axi_sub_agent m_sub_agent;

  // Transfer sequencers of the active manager agents
  axi_txn_sequencer_t m_mgr_sequencers[];
  axi_txn_sequencer_t m_mgr_sequencer;

  // Response policy sequencers of the active subordinate agents
  axi_sub_rsp_sequencer_t m_sub_sequencers[];
  axi_sub_rsp_sequencer_t m_sub_sequencer;

  // Manager sequence results for comparison with monitor observations
  uvm_analysis_port #(axi_agent_mgr_txn) m_mgr_driver_txn_port;

  // Optional predictor and input filter (sequences supply the predictor's map)
  uvm_reg_predictor #(uvm_sequence_item) m_reg_predictor;
  axi_agent_reg_ok_filter                m_reg_filter;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
endclass : axi_agent_virtual_sequencer


function axi_agent_virtual_sequencer::new(string name, uvm_component parent);
  super.new(name, parent);
  m_mgr_driver_txn_port = new("m_mgr_driver_txn_port", this);
endfunction : new
