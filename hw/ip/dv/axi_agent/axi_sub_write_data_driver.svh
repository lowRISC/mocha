// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Drive WREADY using axi_sub_agent_cfg::m_w_ready and pass accepted beats to shared state for
// pairing with AW

class axi_sub_write_data_driver extends axi_sub_driver_base;
  `uvm_component_utils(axi_sub_write_data_driver)

  // Interface, set with set_vif()
  local virtual axi_write_data_if m_vif;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods

  // Call before run_phase
  extern function void set_vif(virtual axi_write_data_if vif);

  extern protected virtual task drive_channel();
  extern protected virtual task drive_idle();
endclass : axi_sub_write_data_driver


function axi_sub_write_data_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sub_write_data_driver::set_vif(virtual axi_write_data_if vif);
  if (vif.if_mode != Subordinate) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Subordinate.",
                         vif.if_mode.name()))
  end
  m_vif = vif;
endfunction : set_vif

task axi_sub_write_data_driver::drive_channel();
  forever begin
    bit waiting;

    @(m_vif.mon_cb);
    if (m_vif.mon_cb.wvalid === 1'b1 && m_vif.mon_cb.wready === 1'b1) begin
      // The bus carries one strobe per data byte (H.c A3.4.4), so ignore the bits above them
      logic [AxiMaxStrbWidth-1:0] strb_mask = (AxiMaxStrbWidth'(1) << (m_vif.data_width / 8)) - 1;

      m_state.add_write_beat(m_vif.mon_cb.wdata, m_vif.mon_cb.wstrb & strb_mask,
                             m_vif.mon_cb.wuser);
    end

    waiting = (m_vif.mon_cb.wvalid === 1'b1 && m_vif.mon_cb.wready !== 1'b1);
    m_vif.sub_cb.wready <= next_ready(m_cfg.m_w_ready, waiting, 1'b1);
  end
endtask : drive_channel

task axi_sub_write_data_driver::drive_idle();
  m_vif.sub_cb.wready <= 1'b0;
endtask : drive_idle
