// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A base class for routing responses from AXI Subordinates to Managers. These are routed based on
// RID / BID.

class axi_response_router extends uvm_component;
  `uvm_component_utils(axi_response_router)

  typedef uvm_sequence_item item_queue_t[$];

  // An associative array that maps ID to a queue of response items that have been seen for that ID
  // (the FIFO works by pop_front and push_back).
  //
  // We never store an empty list as a value in this associative array, so can wait for a response
  // on a given ID by just waiting for the ID to have some value.
  local item_queue_t m_id_to_responses[int unsigned];

  // Queue wait_for_responses tickets per ID in call order. Same-ID responses follow request order
  // (AMBA AXI H.c A5.1); the first caller takes all its requested responses.
  local int unsigned m_id_to_waiters[int unsigned][$];

  local int unsigned m_next_ticket;

  // A flag that is set by assert_reset and cleared by clear_reset. When this is set,
  // m_id_to_responses will be empty and all calls to wait_for_response will return immediately.
  local bit m_in_reset;

  // An event that triggers all waiting tasks. This runs when a new response is added to
  // m_id_to_responses or when a reset is asserted.
  local uvm_event m_update_event;

  // An import for reset events (asserting or clearing reset)
  uvm_analysis_imp #(axi_reset_item, axi_response_router) reset_imp;

  extern function new (string name, uvm_component parent);

  // The write function for reset_imp, which is called when a reset event is broadcast
  extern virtual function void write(axi_reset_item item);

  // Wait for a response to be seen with the given ID.
  //
  // This returns when such a response is seen, setting rsp. If there is a reset, this task will
  // return, setting rsp = null.
  //
  // Equivalent to wait_for_responses with n = 1; call only after sending the request.
  extern task wait_for_response(int unsigned id, output uvm_sequence_item rsp);

  // Return the next n responses for this ID in rsps. Call only after sending the request so same-ID
  // callers queue in bus order and each takes n consecutive responses. Reset returns the responses
  // received so far.
  extern task wait_for_responses(int unsigned id, int unsigned n, output uvm_sequence_item rsps[$]);

  // Notify the router that there has been the given response, for the supplied id.
  extern function void on_response(int unsigned id, uvm_sequence_item rsp);
endclass

function axi_response_router::new(string name, uvm_component parent);
  super.new(name, parent);
  m_update_event = new("m_update_event");
  reset_imp = new("reset_imp", this);
endfunction

function void axi_response_router::write(axi_reset_item item);
  if (item.m_in_reset) begin
    // Reset is being asserted. If we don't know about it already, set a flag, clear
    // m_id_to_responses and trigger the event to cause all tasks waiting to finish.
    if (!m_in_reset) begin
      m_in_reset = 1'b1;
      m_id_to_responses.delete();
      m_id_to_waiters.delete();
      m_update_event.trigger();
    end
  end else begin
    // Reset is being cleared. All we have to do is clear m_in_reset.
    m_in_reset = 1'b0;
  end
endfunction

task axi_response_router::wait_for_response(int unsigned             id,
                                            output uvm_sequence_item rsp);
  uvm_sequence_item rsps[$];

  wait_for_responses(id, 1, rsps);
  rsp = (rsps.size() > 0) ? rsps[0] : null;
endtask

task axi_response_router::wait_for_responses(int unsigned             id,
                                             int unsigned             n,
                                             output uvm_sequence_item rsps[$]);
  int unsigned ticket;

  rsps.delete();
  if (m_in_reset) begin
    return;
  end

  ticket = m_next_ticket++;
  m_id_to_waiters[id].push_back(ticket);

  while (rsps.size() < n) begin
    while (!m_in_reset &&
           !(m_id_to_waiters.exists(id) && m_id_to_waiters[id][0] == ticket &&
             m_id_to_responses.exists(id))) begin
      m_update_event.wait_trigger();
    end
    if (m_in_reset) begin
      return;
    end

    // The logic just below should ensure that m_id_to_responses[id] is never an empty queue, but it
    // probably makes sense to add an extra check here for debugging.
    if (m_id_to_responses[id].size() == 0) begin
      `uvm_fatal(get_full_name(),
                 $sformatf("m_id_to_responses[0x%0h] is an empty queue.", id))
    end

    rsps.push_back(m_id_to_responses[id].pop_front());

    if (m_id_to_responses[id].size() == 0) begin
      m_id_to_responses.delete(id);
    end
  end

  // Wake the next caller, which may already have a queued response
  void'(m_id_to_waiters[id].pop_front());
  if (m_id_to_waiters[id].size() == 0) begin
    m_id_to_waiters.delete(id);
  end
  m_update_event.trigger();
endtask: wait_for_responses

function void axi_response_router::on_response(int unsigned id, uvm_sequence_item rsp);
  if (rsp == null) `uvm_fatal(get_full_name(), "rsp must not be null.")

  if (!m_in_reset) begin
    if (!m_id_to_responses.exists(id)) begin
      m_id_to_responses[id] = '{};
    end
    m_id_to_responses[id].push_back(rsp);
    m_update_event.trigger();
  end
endfunction
