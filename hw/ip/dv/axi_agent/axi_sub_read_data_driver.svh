// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Send read beats after their latency, ordered by axi_sub_state::pick_read_beat, with up to
// axi_sub_agent_cfg::m_max_read_beat_gap idle cycles between beats. Hold RVALID and payload until
// RREADY (AMBA AXI H.c A3.2.1) and assert RLAST on the final beat (A3.2.2).

class axi_sub_read_data_driver extends axi_sub_driver_base;
  `uvm_component_utils(axi_sub_read_data_driver)

  // Interface, set with set_vif()
  local virtual axi_read_data_if m_vif;

  // Read currently driving a beat, or null
  local axi_sub_txn m_cur;

  // Read burst in progress, or null
  local axi_sub_txn m_in_progress;

  // Idle cycles left before the next beat
  local int unsigned m_gap;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods

  // Call before run_phase
  extern function void set_vif(virtual axi_read_data_if vif);

  extern protected virtual task drive_channel();
  extern protected virtual task drive_idle();

  extern local task drive_idle_payload();
endclass : axi_sub_read_data_driver


function axi_sub_read_data_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sub_read_data_driver::set_vif(virtual axi_read_data_if vif);
  if (vif.if_mode != Subordinate) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Subordinate.",
                         vif.if_mode.name()))
  end
  m_vif = vif;
endfunction : set_vif

task axi_sub_read_data_driver::drive_channel();
  forever begin
    @(m_vif.mon_cb);
    wait_for_step(StepResponses);
    if (m_cur != null && m_vif.mon_cb.rvalid === 1'b1 && m_vif.mon_cb.rready === 1'b1) begin
      m_cur.m_beats_sent++;
      if (m_cur.m_beats_sent == m_cur.num_beats()) begin
        m_state.read_done(m_cur);
        m_in_progress = null;
      end else begin
        m_in_progress = m_cur;
      end
      m_cur = null;
      m_gap = $urandom_range(0, m_cfg.m_max_read_beat_gap);
    end

    if (m_cur == null) begin
      if (m_gap > 0) begin
        m_gap--;
      end else begin
        m_cur = m_state.pick_read_beat(m_in_progress);
      end

      if (m_cur == null) begin
        drive_idle_payload();
      end else begin
        m_vif.sub_cb.rvalid <= 1'b1;
        m_vif.sub_cb.rid    <= m_cur.m_req.m_id;
        m_vif.sub_cb.rdata  <= m_cur.m_rdata[m_cur.m_beats_sent];
        m_vif.sub_cb.rresp  <= m_cur.m_rresp[m_cur.m_beats_sent];
        m_vif.sub_cb.rlast  <= (m_cur.m_beats_sent + 1 == m_cur.num_beats());
        m_vif.sub_cb.ruser  <= m_cur.m_policy.m_ruser;
      end
    end
    m_state.tick_reads();
  end
endtask : drive_channel

task axi_sub_read_data_driver::drive_idle();
  m_cur         = null;
  m_in_progress = null;
  m_gap         = 0;
  drive_idle_payload();
endtask : drive_idle

task axi_sub_read_data_driver::drive_idle_payload();
  bit [AxiMaxIdWidth-1:0]    idle_id;
  bit [AxiMaxDataWidth-1:0]  idle_data;
  bit [AxiRespWidth-1:0]     idle_resp;
  bit                        idle_last;
  bit [AxiMaxRUserWidth-1:0] idle_user;

  m_vif.sub_cb.rvalid <= 1'b0;

  // Idle payload is unspecified (see axi_if::drive_x_when_idle)
  if (m_drive_x_when_idle) begin
    m_vif.sub_cb.rid   <= 'x;
    m_vif.sub_cb.rdata <= 'x;
    m_vif.sub_cb.rresp <= 'x;
    m_vif.sub_cb.rlast <= 'x;
    m_vif.sub_cb.ruser <= 'x;
  end else begin
    if (!std::randomize(idle_id, idle_data, idle_resp, idle_last, idle_user)) begin
      `uvm_fatal(get_full_name(), "Failed to randomize the idle R payload.")
    end
    m_vif.sub_cb.rid   <= idle_id;
    m_vif.sub_cb.rdata <= idle_data;
    m_vif.sub_cb.rresp <= idle_resp;
    m_vif.sub_cb.rlast <= idle_last;
    m_vif.sub_cb.ruser <= idle_user;
  end
endtask : drive_idle_payload
