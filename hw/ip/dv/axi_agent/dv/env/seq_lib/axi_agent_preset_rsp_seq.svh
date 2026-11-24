// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A response policy sequence that supplies the items in m_items, in order, and then finishes

class axi_agent_preset_rsp_seq extends axi_sub_rsp_seq;
  `uvm_object_utils(axi_agent_preset_rsp_seq)

  axi_sub_rsp_item m_items[$];

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Add an item that answers with resp, and BUSER and RUSER user, after latency cycles
  extern function void add_item(axi_resp_e resp, int unsigned user, int unsigned latency = 0);
endclass : axi_agent_preset_rsp_seq


function axi_agent_preset_rsp_seq::new(string name = "");
  super.new(name);
endfunction : new

function void axi_agent_preset_rsp_seq::add_item(axi_resp_e resp, int unsigned user,
                                                 int unsigned latency = 0);
  axi_sub_rsp_item item = axi_sub_rsp_item::type_id::create("item");

  item.m_latency     = latency;
  item.m_force_error = (resp != RespOkay);
  item.m_error_resp  = (resp != RespOkay) ? resp : RespSlverr;
  item.m_buser       = user;
  item.m_ruser       = user;
  m_items.push_back(item);
endfunction : add_item

task axi_agent_preset_rsp_seq::body();
  m_sent = 0;
  m_sent_items.delete();
  foreach (m_items[i]) begin
    axi_sub_rsp_item item;

    if (!$cast(item, m_items[i].clone())) begin
      `uvm_fatal(get_full_name(), "Failed to clone an axi_sub_rsp_item.")
    end
    start_item(item);
    finish_item(item);
    m_sent_items.push_back(m_items[i]);
    m_sent++;
  end
endtask : body
