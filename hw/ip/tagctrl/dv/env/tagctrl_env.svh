// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // A manager agent on each of the configuration and tagged subordinates, each taking its bus from
  // config_db, a scoreboard fed by their monitors, and the virtual sequencer. The register model's
  // accesses go through the configuration agent.
  class tagctrl_env extends uvm_env;
    `uvm_component_utils(tagctrl_env)

    // Set by the test before build_phase
    tagctrl_env_cfg cfg;

    axi_mgr_agent             m_cfg_agent;
    axi_mgr_agent             m_tag_agent;
    tagctrl_scoreboard        m_scoreboard;
    tagctrl_virtual_sequencer m_vseqr;

    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (cfg == null) `uvm_fatal(get_full_name(), "cfg is null")
      m_cfg_agent  = axi_mgr_agent::type_id::create("m_cfg_agent", this);
      m_tag_agent  = axi_mgr_agent::type_id::create("m_tag_agent", this);
      m_scoreboard = tagctrl_scoreboard::type_id::create("m_scoreboard", this);
      m_scoreboard.cfg = cfg;
      if (cfg.clk_rst_vif == null) `uvm_fatal(get_full_name(), "cfg.clk_rst_vif is null")
      m_vseqr     = tagctrl_virtual_sequencer::type_id::create("m_vseqr", this);
      m_vseqr.cfg = cfg;
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      if (m_cfg_agent.get_is_active() != UVM_ACTIVE ||
          m_tag_agent.get_is_active() != UVM_ACTIVE) begin
        `uvm_fatal(get_full_name(), "The agents' buses are not in Manager mode")
      end

      m_cfg_agent.m_transaction_port.connect(m_scoreboard.cfg_imp);
      m_tag_agent.m_transaction_port.connect(m_scoreboard.tag_imp);
      m_tag_agent.get_reset_monitor().m_analysis_port.connect(m_scoreboard.reset_imp);

      // The predictor holds the register state, so the mirror is never updated
      cfg.ral.default_map.set_sequencer(m_cfg_agent.get_register_layering_sequencer(),
                                        m_cfg_agent.get_reg_adapter());
      cfg.ral.default_map.set_auto_predict(0);

      m_vseqr.cfg_seqr      = m_cfg_agent.get_sequencer();
      m_vseqr.tag_seqr      = m_tag_agent.get_sequencer();
      m_vseqr.agent_rst_vif = m_tag_agent.get_vif().u_clk_rst_if;
    endfunction

    task run_phase(uvm_phase phase);
      fork
        m_cfg_agent.run_layered_register_vseq();
      join_none
    endtask
  endclass
