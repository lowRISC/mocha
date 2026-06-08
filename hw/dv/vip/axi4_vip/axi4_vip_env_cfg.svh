// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class axi4_vip_env_cfg extends uvm_object;

  string                  m_inst_id                    = "AXI4";
  bit                     m_has_manager                = 0;
  uvm_active_passive_enum m_manager_active_passive     = UVM_PASSIVE;
  bit                     m_has_subordinate            = 0;
  uvm_active_passive_enum m_subordinate_active_passive = UVM_PASSIVE;

  int unsigned m_id_width      = `AXI4_MAX_ID_WIDTH;
  int unsigned m_addr_width    = `AXI4_MAX_ADDR_WIDTH;
  int unsigned m_data_width    = `AXI4_MAX_DATA_WIDTH;
  int unsigned m_user_width    = `AXI4_MAX_USER_WIDTH;
  int unsigned m_region_width  = `AXI4_MAX_REGION_WIDTH;
  int unsigned m_qos_width     = `AXI4_MAX_QOS_WIDTH;

  `uvm_object_utils_begin(axi4_vip_env_cfg)
    `uvm_field_string(m_inst_id, UVM_DEFAULT | UVM_STRING)
    `uvm_field_int(m_has_manager, UVM_DEFAULT)
    `uvm_field_int(m_has_subordinate, UVM_DEFAULT)
    `uvm_field_enum(uvm_active_passive_enum, m_manager_active_passive, UVM_DEFAULT)
    `uvm_field_enum(uvm_active_passive_enum, m_subordinate_active_passive, UVM_DEFAULT)
    `uvm_field_int(m_id_width, UVM_DEFAULT)
    `uvm_field_int(m_addr_width, UVM_DEFAULT)
    `uvm_field_int(m_data_width, UVM_DEFAULT)
    `uvm_field_int(m_user_width, UVM_DEFAULT)
    `uvm_field_int(m_region_width, UVM_DEFAULT)
    `uvm_field_int(m_qos_width, UVM_DEFAULT)
  `uvm_object_utils_end

  extern function new(string name = "");

  // Set the configuration with a single function call.
  //
  // Most arguments translate directly to class variables, but widths have special treatment. A
  // value of zero means the maximum supported width. For example, passing id_width = 0 is the same
  // as passing id_width = `AXI4_MAX_ID_WIDTH.
  //
  // The arguments all have default values that behave the same as the initial values for the class.
  extern virtual function void
    set_config(string                  inst_id = "AXI4",
               bit                     has_manager = 0,
               uvm_active_passive_enum manager_active_passive = UVM_PASSIVE,
               bit                     has_subordinate = 0,
               uvm_active_passive_enum subordinate_active_passive = UVM_PASSIVE,
               int unsigned            id_width = 0,
               int unsigned            addr_width = 0,
               int unsigned            data_width = 0,
               int unsigned            user_width = 0,
               int unsigned            region_width = 0,
               int unsigned            qos_width = 0);

  extern local function int unsigned translate_width(string       field_name,
                                                     int unsigned max_val,
                                                     int unsigned provided);

endclass : axi4_vip_env_cfg

function axi4_vip_env_cfg::new(string name = "");
  super.new(name);
endfunction : new

function void
  axi4_vip_env_cfg::set_config(string                  inst_id = "AXI4",
                               bit                     has_manager = 0,
                               uvm_active_passive_enum manager_active_passive = UVM_PASSIVE,
                               bit                     has_subordinate = 0,
                               uvm_active_passive_enum subordinate_active_passive = UVM_PASSIVE,
                               int unsigned            id_width = 0,
                               int unsigned            addr_width = 0,
                               int unsigned            data_width = 0,
                               int unsigned            user_width = 0,
                               int unsigned            region_width = 0,
                               int unsigned            qos_width = 0);
  m_inst_id                    = inst_id;
  m_has_manager                = has_manager;
  m_manager_active_passive     = manager_active_passive;
  m_has_subordinate            = has_subordinate;
  m_subordinate_active_passive = subordinate_active_passive;

  m_id_width     = translate_width("id_width",     `AXI4_MAX_ID_WIDTH,     id_width);
  m_addr_width   = translate_width("addr_width",   `AXI4_MAX_ADDR_WIDTH,   addr_width);
  m_data_width   = translate_width("data_width",   `AXI4_MAX_DATA_WIDTH,   data_width);
  m_user_width   = translate_width("user_width",   `AXI4_MAX_USER_WIDTH,   user_width);
  m_region_width = translate_width("region_width", `AXI4_MAX_REGION_WIDTH, region_width);
  m_qos_width    = translate_width("qos_width",    `AXI4_MAX_QOS_WIDTH,    qos_width);
endfunction : set_config

function int unsigned axi4_vip_env_cfg::translate_width(string       field_name,
                                                        int unsigned max_val,
                                                        int unsigned provided);
  if (provided == 0) begin
    return max_val;
  end

  if (provided > max_val) begin
    `uvm_error(m_inst_id,
               $sformatf({"Width for %0s cannot be set to %0d. This is greater than %0d ",
                          "(the maximum supported width for this field)."},
                         field_name, provided, max_val))
    return max_val;
  end

  return provided;
endfunction : translate_width
