// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class axi4_vip_driver extends uvm_driver #(axi4_vip_item);

  `uvm_component_utils(axi4_vip_driver)

  axi4_vip_env_cfg        m_cfg;
  virtual axi4_vip_if vif;

  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);

endclass : axi4_vip_driver

function axi4_vip_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_driver::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db#(axi4_vip_env_cfg)::get(this, "", "m_cfg", m_cfg)) begin
    `uvm_fatal("NOCFG", {"Configuration item must be set for: ", get_full_name(), ".m_cfg"})
  end

  if (!uvm_config_db#(virtual axi4_vip_if)::get(this, "", "vif", vif)) begin
    `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
  end
endfunction : build_phase
