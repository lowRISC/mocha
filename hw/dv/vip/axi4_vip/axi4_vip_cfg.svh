// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef AXI4_VIP_CFG_SVH
`define AXI4_VIP_CFG_SVH

class axi4_vip_cfg extends uvm_object;

  // Currently this is a passive VIP (monitor only)
  string                  m_inst_id                    = "AXI4";
  bit                     m_has_manager                = 0;
  uvm_active_passive_enum m_manager_active_passive     = UVM_PASSIVE;
  bit                     m_has_subordinate            = 0;
  uvm_active_passive_enum m_subordinate_active_passive = UVM_PASSIVE;

  // Future placeholders
  bit                     m_has_coverage               = 1;
  bit                     m_has_checker                = 1;

  // actual bus widths (<= max defines)
  int unsigned m_id_width      =  16;
  int unsigned m_addr_width    =  64;
  int unsigned m_data_width    = 512;
  int unsigned m_user_width    =  32;
  int unsigned m_region_width  =   8;
  int unsigned m_qos_width     =   8;

  `uvm_object_utils_begin(axi4_vip_cfg)
    `uvm_field_string(                         m_inst_id,                    UVM_DEFAULT | UVM_STRING)
    `uvm_field_int   (                         m_has_manager,                UVM_DEFAULT)
    `uvm_field_int   (                         m_has_subordinate,            UVM_DEFAULT)
    `uvm_field_int   (                         m_has_coverage,               UVM_DEFAULT)
    `uvm_field_int   (                         m_has_checker,                UVM_DEFAULT)
    `uvm_field_enum  (uvm_active_passive_enum, m_manager_active_passive,     UVM_DEFAULT)
    `uvm_field_enum  (uvm_active_passive_enum, m_subordinate_active_passive, UVM_DEFAULT)
    `uvm_field_int   (                         m_id_width,                   UVM_DEFAULT)
    `uvm_field_int   (                         m_addr_width,                 UVM_DEFAULT)
    `uvm_field_int   (                         m_data_width,                 UVM_DEFAULT)
    `uvm_field_int   (                         m_user_width,                 UVM_DEFAULT)
    `uvm_field_int   (                         m_region_width,               UVM_DEFAULT)
    `uvm_field_int   (                         m_qos_width,                  UVM_DEFAULT)
  `uvm_object_utils_end

  // External Method Declarations
  extern function new(string name="axi4_vip_cfg");

  extern virtual function void set_config(
    string inst_id = "",
    bit has_manager = 0, 
    uvm_active_passive_enum manager_active_passive = UVM_PASSIVE, 
    bit has_subordinate = 0, 
    uvm_active_passive_enum subordinate_active_passive = UVM_PASSIVE, 
    bit has_coverage = 0, 
    bit has_checker = 0,
    int unsigned id_width     =  16,
    int unsigned addr_width   =  64,
    int unsigned data_width   = 512,
    int unsigned user_width   =  32,
    int unsigned region_width =   8,
    int unsigned qos_width    =   8
  );

endclass : axi4_vip_cfg

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function axi4_vip_cfg::new(string name="axi4_vip_cfg");
  super.new(name);
endfunction : new

function void axi4_vip_cfg::set_config(
  string inst_id = "",
  bit has_manager = 0, 
  uvm_active_passive_enum manager_active_passive = UVM_PASSIVE, 
  bit has_subordinate = 0, 
  uvm_active_passive_enum subordinate_active_passive = UVM_PASSIVE, 
  bit has_coverage = 0, 
  bit has_checker = 0,
  int unsigned id_width     =  16,
  int unsigned addr_width   =  64,
  int unsigned data_width   = 512,
  int unsigned user_width   =  32,
  int unsigned region_width =   8,
  int unsigned qos_width    =   8
);
  m_inst_id               = inst_id;
  m_has_manager            = has_manager;
  m_manager_active_passive = manager_active_passive;
  m_has_subordinate             = has_subordinate;
  m_subordinate_active_passive  = subordinate_active_passive;
  m_has_coverage          = has_coverage;
  m_has_checker           = has_checker;
  m_id_width              = id_width;
  m_addr_width            = addr_width;
  m_data_width            = data_width;
  m_user_width            = user_width;
  m_region_width          = region_width;
  m_qos_width             = qos_width;
endfunction : set_config

`endif // AXI4_VIP_CFG_SVH