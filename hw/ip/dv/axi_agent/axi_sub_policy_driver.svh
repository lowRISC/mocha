// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Prefetch response policies into a depth-1 mailbox so AW and AR can take them in zero time at
// acceptance. Transactions take items in acceptance order, with writes first when AW and AR
// handshake at the same edge. If the mailbox is empty, take_policy() uses configuration defaults.

class axi_sub_policy_driver extends uvm_driver #(axi_sub_rsp_item);
  `uvm_component_utils(axi_sub_policy_driver)

  // Configuration, set with set_cfg()
  local axi_sub_agent_cfg m_cfg;

  // Next response policy. fetch_policy may hold another item while waiting for mailbox space, so
  // the sequencer runs at most two items ahead of the bus.
  local mailbox #(axi_sub_rsp_item) m_mb;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern virtual task run_phase(uvm_phase phase);

  // Class specific methods

  // Call before run_phase
  extern function void set_cfg(axi_sub_agent_cfg cfg);

  // Take the prefetched policy and set from_seq, or use configuration defaults. AR calls after the
  // edge's NBA region so a write accepted at that edge takes its item first.
  extern function void take_policy(output axi_sub_rsp_item policy, output bit from_seq);

  // Keep the mailbox filled, running forever
  extern local task fetch_policy();
endclass : axi_sub_policy_driver


function axi_sub_policy_driver::new(string name, uvm_component parent);
  super.new(name, parent);
  m_mb = new(1);
endfunction : new

function void axi_sub_policy_driver::set_cfg(axi_sub_agent_cfg cfg);
  if (m_cfg != null) begin
    `uvm_fatal(get_full_name(), "Cannot call set_cfg: there is already a configuration.")
  end
  m_cfg = cfg;
endfunction : set_cfg

task axi_sub_policy_driver::run_phase(uvm_phase phase);
  if (m_cfg == null) begin
    `uvm_fatal(get_full_name(), "Cannot supply policy: cfg is null.")
  end
  fetch_policy();
endtask : run_phase

task axi_sub_policy_driver::fetch_policy();
  forever begin
    axi_sub_rsp_item req_item;
    axi_sub_rsp_item policy;

    seq_item_port.get_next_item(req_item);

    // Copy the item before the sequence can reuse it
    if (!$cast(policy, req_item.clone())) begin
      `uvm_fatal(get_full_name(), "Failed to clone the response policy item.")
    end

    // Release the sequence before waiting for mailbox space
    seq_item_port.item_done();
    m_mb.put(policy);
  end
endtask : fetch_policy

function void axi_sub_policy_driver::take_policy(output axi_sub_rsp_item policy,
                                                 output bit              from_seq);
  from_seq = m_mb.try_get(policy);
  if (from_seq) begin
    return;
  end

  policy = axi_sub_rsp_item::type_id::create("default_policy");
  policy.m_latency     = m_cfg.m_default_latency;
  policy.m_force_error = 1'b0;
  policy.m_error_resp  = RespSlverr;
  policy.m_buser       = '0;
  policy.m_ruser       = '0;
endfunction : take_policy
