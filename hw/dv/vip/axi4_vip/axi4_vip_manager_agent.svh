// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class axi4_vip_manager_agent extends uvm_agent;

  `uvm_component_utils(axi4_vip_manager_agent)

  axi4_vip_env_cfg       m_cfg;

  axi4_vip_monitor   m_monitor;

  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);

endclass : axi4_vip_manager_agent

function axi4_vip_manager_agent::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_manager_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (!uvm_config_db#(axi4_vip_env_cfg)::get(this, "", "m_cfg", m_cfg)) begin
    `uvm_fatal("NOCFG", {"Configuration item must be set for: ", get_full_name(), ".m_cfg"})
  end

  if (m_cfg.m_manager_active_passive == UVM_ACTIVE) begin
    `uvm_fatal("BADCFG", "Active manager mode is not implemented")
  end

  m_monitor = axi4_vip_monitor::type_id::create("m_monitor", this);
endfunction : build_phase
