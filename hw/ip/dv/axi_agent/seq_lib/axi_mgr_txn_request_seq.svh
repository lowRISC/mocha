// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A sequence that sends a single item (a write request (AW) or read request (AR) transfer)
//
// The item is neither created nor randomised here: a sequence that wants to use this one should
// build the request itself and provide it before starting. Randomising a level up is what lets the
// caller solve the request alongside its own constraints, which is how the burst sequences tie
// AxLEN to the number of data beats they are about to send.
//
// When the sequence completes, the rsp field will contain a status item that shows whether the
// sequence ran to completion (rather than being interrupted by a reset).

class axi_mgr_txn_request_seq extends uvm_sequence #(axi_txn_request_item, axi_status_item);
  `uvm_object_utils(axi_mgr_txn_request_seq)

  // The item to send. Provide this before starting the sequence.
  axi_txn_request_item m_req;

  extern function new(string name="");

  // Check that m_req was provided before start().
  extern virtual task pre_start();

  extern task body();
endclass

function axi_mgr_txn_request_seq::new(string name="");
  super.new(name);
endfunction

task axi_mgr_txn_request_seq::pre_start();
  super.pre_start();
  if (m_req == null) `uvm_fatal(get_full_name(), "Cannot run sequence with no item.")
endtask

task axi_mgr_txn_request_seq::body();
  uvm_sequence_item base_status_item;

  // Send the caller-supplied item verbatim: it is already built, so no randomisation.
  start_item(m_req);
  finish_item(m_req);

  // Get a response, which will always be sent by the driver (and is available already: there's no
  // pipelining and finish_item just completed).
  get_base_response(base_status_item);
  if (!$cast(rsp, base_status_item)) begin
    `uvm_fatal(get_full_name(), "Status response is not an axi_status_item")
  end
endtask
