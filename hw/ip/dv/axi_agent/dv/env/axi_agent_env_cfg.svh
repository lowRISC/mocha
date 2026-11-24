// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Environment configuration for the AXI agent self-test

class axi_agent_env_cfg extends dv_base_env_cfg;
  `uvm_object_utils(axi_agent_env_cfg)

  // The link under test, chosen with +axi_link
  axi_agent_link_cfg m_link;

  // Subordinate configurations shared with the scoreboard. m_sub_agent_cfg is the first, and only
  // the crossbar has more than one.
  axi_sub_agent_cfg m_sub_agent_cfgs[];
  axi_sub_agent_cfg m_sub_agent_cfg;

  // Manager and subordinate bus properties, copied from interfaces by axi_agent_env. m_id_width and
  // m_user_width are the narrower of the AW and AR widths, which random requests fit.
  int unsigned m_addr_width;
  int unsigned m_data_width;
  int unsigned m_id_width;
  int unsigned m_user_width;
  int unsigned m_awuser_width;
  int unsigned m_aruser_width;
  int unsigned m_wuser_width;
  int unsigned m_buser_width;
  int unsigned m_ruser_width;
  bit          m_is_lite;
  int unsigned m_sub_id_width;
  int unsigned m_sub_buser_width;
  int unsigned m_sub_ruser_width;
  bit          m_sub_is_lite;

  // Expect a sequence record for every manager transfer (disabled for register-layer tests and
  // external managers)
  bit m_mgr_records = 1'b1;

  // Build a predictor from the first manager's monitor (enabled by +axi_reg_predictor)
  bit m_reg_predictor = 1'b0;

  // Whether every request at a manager end must carry the AxPROT value m_fixed_prot
  bit                    m_has_fixed_prot = 1'b0;
  bit [AxiProtWidth-1:0] m_fixed_prot;

  // Use axi_agent_mapped_mem for subordinate memory, mapping m_mapped_lo through m_mapped_hi
  bit                       m_mapped_mem = 1'b0;
  bit [AxiMaxAddrWidth-1:0] m_mapped_lo;
  bit [AxiMaxAddrWidth-1:0] m_mapped_hi;

  // Response policy sequences in start order, per subordinate, for scoreboard policy-order checks
  axi_sub_rsp_seq m_rsp_seqs[int unsigned][$];

  // Minimum activity counts checked in check_phase (see axi_agent_scoreboard::get_count)
  int unsigned m_min_counts[string];

  // The probe on the bus at the (first) manager end, and the control of a pulp_axi manager
  virtual axi_agent_probe_if     m_probe_vif;
  virtual axi_agent_pulp_ctrl_if m_pulp_ctrl_vif;

  // The probes on every bus of the link
  virtual axi_agent_probe_if m_bus_probe_vifs[$];

  // Randomize idle payload policy per run unless +axi_drive_x_when_idle fixes it (see
  // axi_if::drive_x_when_idle)
  rand bit m_drive_x_when_idle;

  // Randomize legal subordinate settings. A nonzero default byte exposes managers that read X as
  // zero.
  rand bit       m_zero_inactive_lanes;
  rand bit [7:0] m_default_byte;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern function void post_randomize();

  // Class specific methods
  extern virtual function void initialize();

  // pulp_axi applies at 2ns and samples at 8ns after each rising edge, which requires a 10ns clock
  extern constraint pulp_clk_c;

  // Favor idle X to expose sampling outside handshakes
  extern constraint drive_x_when_idle_c;

  // Favor zeroed inactive lanes but also exercise nonzero lanes
  extern constraint zero_inactive_lanes_c;
  extern constraint default_byte_c;
endclass : axi_agent_env_cfg


function axi_agent_env_cfg::new(string name = "");
  super.new(name);
endfunction : new

function void axi_agent_env_cfg::initialize();
  string link_name = "agent";

  // No register model, so set the flag checked by dv_base_env_cfg::pre_randomize
  is_initialized = 1'b1;
  ral_model_names.delete();

  void'($value$plusargs("axi_link=%s", link_name));
  void'($value$plusargs("axi_reg_predictor=%0b", m_reg_predictor));
  m_link = axi_agent_link_cfg::type_id::create("m_link");
  m_link.configure(link_name);
  m_mgr_records = m_link.m_mgr_is_agent;

  m_sub_agent_cfgs = new[m_link.m_num_subs];
  foreach (m_sub_agent_cfgs[i]) begin
    m_sub_agent_cfgs[i] = axi_sub_agent_cfg::type_id::create($sformatf("m_sub_agent_cfgs[%0d]", i));
    m_sub_agent_cfgs[i].m_mem = axi_mem_model_t::type_id::create($sformatf("m_mem[%0d]", i));
  end
  m_sub_agent_cfg = m_sub_agent_cfgs[0];
endfunction : initialize

function void axi_agent_env_cfg::post_randomize();
  super.post_randomize();
  void'($value$plusargs("axi_drive_x_when_idle=%0b", m_drive_x_when_idle));
  foreach (m_sub_agent_cfgs[i]) begin
    m_sub_agent_cfgs[i].m_zero_inactive_lanes = m_zero_inactive_lanes;
    m_sub_agent_cfgs[i].m_default_byte        = m_default_byte;
  end
endfunction : post_randomize

constraint axi_agent_env_cfg::pulp_clk_c {
  m_link.m_name != "agent" -> clk_freq_mhz == 100;
}

constraint axi_agent_env_cfg::drive_x_when_idle_c {
  m_drive_x_when_idle dist {1'b1 := 3, 1'b0 := 1};
}

constraint axi_agent_env_cfg::zero_inactive_lanes_c {
  m_zero_inactive_lanes dist {1'b1 := 3, 1'b0 := 1};
}

constraint axi_agent_env_cfg::default_byte_c {
  m_default_byte != 8'h00;
}
