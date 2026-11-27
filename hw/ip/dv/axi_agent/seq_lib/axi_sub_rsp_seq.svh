// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Random response-policy sequence for an AXI subordinate agent

class axi_sub_rsp_seq extends uvm_sequence #(axi_sub_rsp_item);
  `uvm_object_utils(axi_sub_rsp_seq)

  // Latency bounds before BVALID or first RVALID
  int unsigned m_latency_min = 0;
  int unsigned m_latency_max = 0;

  // The percentage of transactions answered with an error response, SLVERR or DECERR
  int unsigned m_error_pct = 0;

  // Item count (zero runs until m_stop)
  int unsigned m_num_items = 0;

  // Stop between items while the driver requests policies. Use stop() for an idle bus.
  bit m_stop = 1'b0;

  // Items taken by the driver, used to distinguish an idle sequence from one that never ran
  int unsigned m_sent = 0;

  // Copies of supplied policies in order, for checking transaction assignment
  axi_sub_rsp_item m_sent_items[$];

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Stop immediately, including while start_item is blocked on an idle bus
  extern function void stop();
endclass : axi_sub_rsp_seq


function axi_sub_rsp_seq::new(string name = "");
  super.new(name);
endfunction : new

function void axi_sub_rsp_seq::stop();
  m_stop = 1'b1;
  if (get_sequence_state() inside {UVM_PRE_BODY, UVM_BODY, UVM_POST_BODY}) begin
    kill();
  end
endfunction : stop

task axi_sub_rsp_seq::body();
  m_sent = 0;
  m_sent_items.delete();

  forever begin
    axi_sub_rsp_item item = axi_sub_rsp_item::type_id::create("item");
    axi_sub_rsp_item sent;

    start_item(item);
    item.m_latency_min = m_latency_min;
    item.m_latency_max = m_latency_max;
    item.m_error_pct   = m_error_pct;
    if (!item.randomize()) begin
      `uvm_fatal(get_full_name(), "Failed to randomise an axi_sub_rsp_item.")
    end
    finish_item(item);

    if (!$cast(sent, item.clone())) begin
      `uvm_fatal(get_full_name(), "Failed to clone an axi_sub_rsp_item.")
    end
    m_sent_items.push_back(sent);
    m_sent++;
    if (m_num_items != 0 && m_sent >= m_num_items) begin
      break;
    end
    if (m_stop) begin
      break;
    end
  end
endtask : body
