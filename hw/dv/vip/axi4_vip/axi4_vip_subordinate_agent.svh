// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef __AXI4_VIP_subordinate_AGENT_SVH
`define __AXI4_VIP_subordinate_AGENT_SVH

class axi4_vip_subordinate_agent extends uvm_agent;

  `uvm_component_utils(axi4_vip_subordinate_agent)

  axi4_vip_cfg       m_cfg;

  axi4_vip_monitor   m_monitor;
  axi4_vip_driver    m_driver;
  axi4_vip_sequencer m_sequencer;

  // External Method Declarations
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

endclass : axi4_vip_subordinate_agent

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function axi4_vip_subordinate_agent::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_subordinate_agent::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (!uvm_config_db#(axi4_vip_cfg)::get(this,"","m_cfg",m_cfg)) begin
    `uvm_fatal("NOCFG", {"Configuration item  must be set for: ", get_full_name(), "m_config"})
  end

  m_monitor = axi4_vip_monitor::type_id::create("m_monitor", this);

  // Future placeholder
  if (m_cfg.m_subordinate_active_passive == UVM_ACTIVE) begin
    m_driver    = axi4_vip_driver   ::type_id::create("m_driver", this);
    m_sequencer = axi4_vip_sequencer::type_id::create("m_sequencer", this);
  end
endfunction : build_phase

function void axi4_vip_subordinate_agent::connect_phase(uvm_phase phase);
  // Future placeholder, UVM_ACTIVE is not supported
  if (m_cfg.m_subordinate_active_passive == UVM_ACTIVE) begin
    m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
  end
endfunction : connect_phase

`endif // __AXI4_VIP_subordinate_AGENT_SVH