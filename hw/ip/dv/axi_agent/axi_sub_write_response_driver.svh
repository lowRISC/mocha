// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Respond when AW, all W data and latency are complete, ordered by
// axi_sub_state::pick_write_response. Hold BVALID and payload until BREADY (AMBA AXI H.c A3.2.1).

class axi_sub_write_response_driver extends axi_sub_driver_base;
  `uvm_component_utils(axi_sub_write_response_driver)

  // Interface, set with set_vif()
  local virtual axi_write_response_if m_vif;

  // Write currently driving a response, or null
  local axi_sub_txn m_cur;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods

  // Call before run_phase
  extern function void set_vif(virtual axi_write_response_if vif);

  extern protected virtual task drive_channel();
  extern protected virtual task drive_idle();

  extern local task drive_idle_payload();
endclass : axi_sub_write_response_driver


function axi_sub_write_response_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sub_write_response_driver::set_vif(virtual axi_write_response_if vif);
  if (vif.if_mode != Subordinate) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Subordinate.",
                         vif.if_mode.name()))
  end
  m_vif = vif;
endfunction : set_vif

task axi_sub_write_response_driver::drive_channel();
  forever begin
    @(m_vif.mon_cb);
    wait_for_step(StepResponses);
    if (m_cur != null && m_vif.mon_cb.bvalid === 1'b1 && m_vif.mon_cb.bready === 1'b1) begin
      m_state.write_done(m_cur);
      m_cur = null;
    end

    if (m_cur == null) begin
      m_cur = m_state.pick_write_response();
      if (m_cur == null) begin
        drive_idle_payload();
      end else begin
        m_vif.sub_cb.bvalid <= 1'b1;
        m_vif.sub_cb.bid    <= m_cur.m_req.m_id;
        m_vif.sub_cb.bresp  <= m_cur.m_bresp;
        m_vif.sub_cb.buser  <= m_cur.m_policy.m_buser;
      end
    end
    m_state.tick_writes();
  end
endtask : drive_channel

task axi_sub_write_response_driver::drive_idle();
  m_cur = null;
  drive_idle_payload();
endtask : drive_idle

task axi_sub_write_response_driver::drive_idle_payload();
  bit [AxiMaxIdWidth-1:0]       idle_id;
  bit [AxiRespWidth-1:0]        idle_resp;
  bit [AxiMaxRespUserWidth-1:0] idle_user;

  m_vif.sub_cb.bvalid <= 1'b0;

  // Idle payload is unspecified (see axi_if::drive_x_when_idle)
  if (m_drive_x_when_idle) begin
    m_vif.sub_cb.bid   <= 'x;
    m_vif.sub_cb.bresp <= 'x;
    m_vif.sub_cb.buser <= 'x;
  end else begin
    if (!std::randomize(idle_id, idle_resp, idle_user)) begin
      `uvm_fatal(get_full_name(), "Failed to randomize the idle B payload.")
    end
    m_vif.sub_cb.bid   <= idle_id;
    m_vif.sub_cb.bresp <= idle_resp;
    m_vif.sub_cb.buser <= idle_user;
  end
endtask : drive_idle_payload
