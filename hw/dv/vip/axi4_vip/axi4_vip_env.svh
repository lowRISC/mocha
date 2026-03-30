// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef AXI4_VIP_ENV_SVH
`define AXI4_VIP_ENV_SVH

class axi4_vip_env extends uvm_env;

  `uvm_component_utils(axi4_vip_env)

  axi4_vip_cfg m_cfg;

  axi4_vip_master_agent m_master;
  axi4_vip_slave_agent  m_slave;

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

  if (m_cfg.m_has_master == 1) begin
    m_master = axi4_vip_master_agent::type_id::create("m_master", this);
  end

  if (m_cfg.m_has_slave == 1) begin
    m_slave = axi4_vip_slave_agent::type_id::create("m_slave", this);
  end
endfunction : build_phase

`endif // AXI4_VIP_ENV_SVH