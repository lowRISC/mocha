// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class axi4_vip_env extends uvm_env;

  `uvm_component_utils(axi4_vip_env)

  axi4_vip_cfg m_cfg;

  axi4_vip_manager_agent m_manager;
  axi4_vip_subordinate_agent  m_subordinate;

  // External Method Declarations
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);

endclass : axi4_vip_env

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function axi4_vip_env::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (! uvm_config_db #(axi4_vip_cfg)::get(this, "", "m_cfg", m_cfg)) begin
    `uvm_fatal("NOCFG", {"Configuration item  must be set for: ", get_full_name(), "m_cfg"})
  end

  if (m_cfg.m_has_manager == 1) begin
    m_manager = axi4_vip_manager_agent::type_id::create("m_manager", this);
  end

  if (m_cfg.m_has_subordinate == 1) begin
    m_subordinate = axi4_vip_subordinate_agent::type_id::create("m_subordinate", this);
  end
endfunction : build_phase
