// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The configuration for an agent driving the interfaces for AXI (AW, W, B, AR, R).

class axi_agent_cfg extends uvm_object;
  `uvm_object_utils(axi_agent_cfg)

  // Interfaces
  virtual clk_rst_if            clk_rst_vif;        // ACLK/ARESETn

  virtual axi_write_request_if  write_request_vif;
  virtual axi_write_data_if     write_data_vif;
  virtual axi_write_response_if write_response_vif;
  virtual axi_read_request_if   read_request_vif;
  virtual axi_read_data_if      read_data_vif;

  // ID and knobs
  string                  inst_id         = "axi_mgr";    // tag for logging
  uvm_active_passive_enum is_active       = UVM_ACTIVE;   // gates the driver; the monitor is always built
  bit                     enable_coverage = 1'b0;

  extern function new(string name = "axi_agent_cfg");

  // Set the config fields in one call. Interfaces are set by the VIP instantiation.
  extern function void set_config(string                  inst_id         = "axi_mgr",
                                  uvm_active_passive_enum is_active       = UVM_ACTIVE,
                                  bit                     enable_coverage = 1'b0);
endclass

function axi_agent_cfg::new(string name = "axi_agent_cfg");
  super.new(name);
endfunction

function void axi_agent_cfg::set_config(string                  inst_id         = "axi_mgr",
                                        uvm_active_passive_enum is_active       = UVM_ACTIVE,
                                        bit                     enable_coverage = 1'b0);
  this.inst_id         = inst_id;
  this.is_active       = is_active;
  this.enable_coverage = enable_coverage;
endfunction
