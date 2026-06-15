// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A virtual sequence that sends a single AXI write with AWBURST set to FIXED and AWLEN = 0 (so
// there is a single data transfer)
//
// The single request item is a randomised field (m_fixed_req) and the response is created in the
// rsp field, which will be created before the sequence completes.

class axi_mgr_write_fixed_vseq extends uvm_sequence#(uvm_sequence_item, axi_fixed_write_rsp_item);
  `uvm_object_utils(axi_mgr_write_fixed_vseq)

  // The write response router. Set this by calling set_write_response_router before starting the
  // sequence.
  local axi_response_router        m_write_response_router;

  // Sequencers for AW, W and B. Set these by calling set_sequencers before starting the sequence.
  local write_request_sequencer_t  m_write_request_sequencer;
  local write_data_sequencer_t     m_write_data_sequencer;
  local write_response_sequencer_t m_write_response_sequencer;

  // An item representing the single request that will be sent.
  rand axi_fixed_write_req_item m_fixed_req;

  extern function new(string name="");
  extern task body();

  // Set the write response router
  extern function void set_write_response_router(axi_response_router router);

  // Set sequencers for the AW, W and B channels
  extern function void set_sequencers(write_request_sequencer_t  write_request_sequencer,
                                      write_data_sequencer_t     write_data_sequencer,
                                      write_response_sequencer_t write_response_sequencer);
endclass

function axi_mgr_write_fixed_vseq::new(string name="");
  super.new(name);
  m_fixed_req = axi_fixed_write_req_item::type_id::create("m_fixed_req");
endfunction

task axi_mgr_write_fixed_vseq::body();
  axi_mgr_txn_request_seq       aw_seq;
  axi_txn_request_item          aw_req;
  axi_mgr_write_single_data_seq w_seq;
  axi_mgr_write_response_seq    b_seq;
  uvm_sequence_item             write_response_item;
  axi_write_response_item       write_response;

  if (m_write_response_router == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because there is no write response router.")
  end

  if (m_write_request_sequencer == null ||
      m_write_data_sequencer == null ||
      m_write_response_sequencer == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because sequencers are not all set.")
  end

  // Build the write request (AW) to send. All the fields were chosen when this virtual sequence was
  // randomised, so set them directly. BurstFixed with AWLEN = 0 is what makes this a single
  // transfer.
  aw_req = axi_txn_request_item::type_id::create("aw_req");
  aw_req.m_id     = m_fixed_req.m_id;
  aw_req.m_addr   = m_fixed_req.m_addr;
  aw_req.m_region = m_fixed_req.m_region;
  aw_req.m_len    = 8'd0;
  aw_req.m_size   = m_fixed_req.m_size;
  aw_req.m_burst  = BurstFixed;
  aw_req.m_lock   = m_fixed_req.m_lock;
  aw_req.m_cache  = m_fixed_req.m_cache;
  aw_req.m_prot   = m_fixed_req.m_prot;
  aw_req.m_qos    = m_fixed_req.m_qos;
  aw_req.m_user   = m_fixed_req.m_user;

  // Check the request is AXI-legal.
  if (!aw_req.randomize(null)) begin
    `uvm_error(get_full_name(),
               "AW request violates AXI legality constraints (see axi_txn_request_item)")
  end

  // Construct the write request sequence (AW), handing it aw_req to send verbatim.
  aw_seq = axi_mgr_txn_request_seq::type_id::create("aw_seq");
  aw_seq.m_req = aw_req;

  // Create the sequence to send the write data (W). Its m_write_data_item field doesn't need
  // randomising: we can just set it to equal the value of m_fixed_req.m_write_data_item.
  w_seq = axi_mgr_write_single_data_seq::type_id::create("w_seq");
  w_seq.m_write_data_item.rand_mode(0);
  if (!w_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize w_seq.")
  end
  w_seq.m_write_data_item.copy(m_fixed_req.m_write_data_item);

  // Create a sequence to receive a single write response (B). (This might or might not match our
  // ID, but that doesn't matter: the point is that we need to send it as a token)
  b_seq = axi_mgr_write_response_seq::type_id::create("b_seq");
  if (!b_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize b_seq.")
  end

  // Run the sequence to consume a write response in the background. The response in question might
  // not be for the ID we're tracking, so we don't wait directly for it to finish.
  fork begin
    b_seq.start(m_write_response_sequencer);

    // Once the B channel sequence has finished, pass its response to the router (unless there is no
    // response, which means that both it and the router are seeing a reset).
    if (b_seq.rsp != null) begin
      m_write_response_router.on_response(b_seq.rsp.m_id, b_seq.rsp);
    end
  end join_none

  // Run the other sequences. This waits for aw_seq and w_seq to complete and also waits for a
  // response from m_write_response_router (which may or may not be the response to b_seq).
  fork
    aw_seq.start(m_write_request_sequencer);
    w_seq.start(m_write_data_sequencer);
    m_write_response_router.wait_for_response(m_fixed_req.m_id, write_response_item);
  join

  // At this point, the AW and W sequences have completed (either by sending their items or by
  // seeing a reset) and wait_for_response has completed, writing write_response_item (which is
  // null on reset). Downcast it to the concrete axi_write_response_item type.
  if (!$cast(write_response, write_response_item))
    `uvm_fatal(get_full_name(), "wait_for_response returned unexpected item type")

  rsp = axi_fixed_write_rsp_item::type_id::create("rsp");
  rsp.m_aw_status      = aw_seq.rsp;
  rsp.m_w_status       = w_seq.rsp;
  rsp.m_write_response = write_response;
endtask

function void axi_mgr_write_fixed_vseq::set_write_response_router(axi_response_router router);
  if (router == null) `uvm_fatal(get_full_name(), "Router is null.")
  m_write_response_router = router;
endfunction

function void
  axi_mgr_write_fixed_vseq::set_sequencers(write_request_sequencer_t  write_request_sequencer,
                                           write_data_sequencer_t     write_data_sequencer,
                                           write_response_sequencer_t write_response_sequencer);
  if (write_request_sequencer == null)  `uvm_fatal(get_full_name(), "No write_request_sequencer.")
  if (write_data_sequencer == null)     `uvm_fatal(get_full_name(), "No write_data_sequencer.")
  if (write_response_sequencer == null) `uvm_fatal(get_full_name(), "No write_response_sequencer.")

  m_write_request_sequencer  = write_request_sequencer;
  m_write_data_sequencer     = write_data_sequencer;
  m_write_response_sequencer = write_response_sequencer;
endfunction
