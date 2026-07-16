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

  extern function new(string name = "");
endclass

function axi_agent_cfg::new(string name = "");
  super.new(name);
endfunction
