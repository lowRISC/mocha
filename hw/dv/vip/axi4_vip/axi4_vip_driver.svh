// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef AXI4_VIP_DRIVER_SVH
`define AXI4_VIP_DRIVER_SVH

class axi4_vip_driver extends uvm_driver #(axi4_vip_item);

  `uvm_component_utils(axi4_vip_driver)

  axi4_vip_cfg        m_cfg;
  virtual axi4_vip_if vif;

  // External Method Declarations
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

endclass : axi4_vip_driver

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function axi4_vip_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_driver::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (! uvm_config_db #(axi4_vip_cfg)::get(this, "", "m_cfg", m_cfg)) begin
     `uvm_fatal("NOCFG", {"Configuration item  must be set for: ", get_full_name(), "m_cfg"})
  end

  if (! uvm_config_db #(virtual interface axi4_vip_if)::get(this, get_full_name(),"vif", vif)) begin
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"})
  end
endfunction : build_phase

task axi4_vip_driver::run_phase(uvm_phase phase);
  forever begin
    // TODO: Placeholder
    seq_item_port.get_next_item(req);
    seq_item_port.item_done();
  end
endtask : run_phase

`endif // AXI4_VIP_DRIVER_SVH