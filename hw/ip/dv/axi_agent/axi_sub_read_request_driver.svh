// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Drive ARREADY using axi_sub_agent_cfg::m_ar_ready and hold it low at m_max_outstanding_reads.
// Record accepted requests and their response policies in shared state.

class axi_sub_read_request_driver extends axi_sub_driver_base;
  `uvm_component_utils(axi_sub_read_request_driver)

  // Each accepted request with the response policy it was given (see get_accept_record)
  uvm_analysis_port #(axi_sub_txn) m_accept_port;

  // Interface, set with set_vif()
  local virtual axi_read_request_if m_vif;

  // Response policy source, set with set_vif()
  local axi_sub_policy_driver m_policy_driver;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);

  // Class specific methods

  // Call before run_phase
  extern function void set_vif(virtual axi_read_request_if vif,
                               axi_sub_policy_driver       policy_driver);

  extern protected virtual task drive_channel();
  extern protected virtual task drive_idle();
endclass : axi_sub_read_request_driver


function axi_sub_read_request_driver::new(string name, uvm_component parent);
  super.new(name, parent);
  m_accept_port = new("m_accept_port", this);
endfunction : new

function void axi_sub_read_request_driver::set_vif(virtual axi_read_request_if vif,
                                                   axi_sub_policy_driver       policy_driver);
  if (vif.if_mode != Subordinate) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Subordinate.",
                         vif.if_mode.name()))
  end
  m_vif           = vif;
  m_policy_driver = policy_driver;
endfunction : set_vif

task axi_sub_read_request_driver::drive_channel();
  forever begin
    bit waiting;

    @(m_vif.mon_cb);
    if (m_vif.mon_cb.arvalid === 1'b1 && m_vif.mon_cb.arready === 1'b1) begin
      axi_txn_request_item req = axi_txn_request_item::type_id::create("ar_req");
      axi_sub_rsp_item     policy;
      bit                  from_seq;
      axi_sub_txn          txn;

      req.m_id     = m_vif.mon_cb.arid & m_vif.arid_mask;
      req.m_addr   = m_vif.mon_cb.araddr & m_vif.araddr_mask;
      req.m_region = m_vif.mon_cb.arregion;
      req.m_len    = m_vif.mon_cb.arlen;
      req.m_size   = m_vif.mon_cb.arsize;
      req.m_burst  = burst_e'(m_vif.mon_cb.arburst);
      req.m_lock   = m_vif.mon_cb.arlock;
      req.m_cache  = m_vif.mon_cb.arcache;
      req.m_prot   = m_vif.mon_cb.arprot;
      req.m_qos    = m_vif.mon_cb.arqos;
      req.m_user   = m_vif.mon_cb.aruser & m_vif.aruser_mask;

      // A write accepted at this edge takes its policy item first
      wait_for_step(StepReads);
      m_policy_driver.take_policy(policy, from_seq);
      txn = m_state.add_read_request(req, policy);
      txn.m_policy_from_seq = from_seq;
      m_accept_port.write(txn.get_accept_record());
    end

    waiting = (m_vif.mon_cb.arvalid === 1'b1 && m_vif.mon_cb.arready !== 1'b1);
    m_vif.sub_cb.arready <= next_ready(m_cfg.m_ar_ready, waiting, m_state.can_accept_read());
  end
endtask : drive_channel

task axi_sub_read_request_driver::drive_idle();
  m_vif.sub_cb.arready <= 1'b0;
endtask : drive_idle
