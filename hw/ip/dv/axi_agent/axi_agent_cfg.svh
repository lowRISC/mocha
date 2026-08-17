// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The configuration for an agent driving the interfaces for AXI (AW, W, B, AR, R).

class axi_agent_cfg extends uvm_object;
  `uvm_object_utils(axi_agent_cfg)

  // UVM_ACTIVE if the agent should build drivers, sequencers, and monitors. 
  // UVM_PASSIVE if it should build only the monitors. Set directly by whoever builds the cfg.
  uvm_active_passive_enum is_active = UVM_ACTIVE;

  // Interfaces
  virtual clk_rst_if            clk_rst_vif;        // ACLK/ARESETn

  virtual axi_write_request_if  write_request_vif;
  virtual axi_write_data_if     write_data_vif;
  virtual axi_write_response_if write_response_vif;
  virtual axi_read_request_if   read_request_vif;
  virtual axi_read_data_if      read_data_vif;

  // How the manager drives the payload of an idle channel, where AXI requires nothing of it. When
  // set, every field but the valid is driven X, so a subordinate that samples outside the
  // VALID/READY handshake propagates the X instead of quietly reading a plausible value. When
  // clear, the payload is randomised instead: still meaningless, but defined.
  //
  // Defaults set, so an idle channel drives X.
  bit drive_x_when_idle = 1'b1;

  extern function new(string name = "");
endclass

function axi_agent_cfg::new(string name = "");
  super.new(name);
endfunction
