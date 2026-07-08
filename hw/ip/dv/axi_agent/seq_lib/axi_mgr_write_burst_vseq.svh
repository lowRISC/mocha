// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A virtual sequence that sends a single AXI write burst of arbitrary length. This is the
// multi-beat generalisation of axi_mgr_write_fixed_vseq.
//
// To use it:
//
//   - Create it, then call set_sequencers() and set_write_response_router(). Both are required:
//      body() fatals if either is missing.
//   - Fill m_data_items with one write data item per beat, in order, before randomising this
//      sequence. This is required: body() fatals if it is empty. The beats are sent verbatim
//      except WLAST, which is forced on the final beat.
//   - Choose the rest of the request by randomising this sequence. m_aw_req is rand, so a plain
//      randomize() picks legal AW fields and len_matches_data_c ties AWLEN to the beat count. To
//      direct the burst, constrain the fields that matter in the same call:
//
//        if (!vseq.randomize() with { m_aw_req.m_addr  == 'h1000;
//                                     m_aw_req.m_burst == BurstIncr; }) ...
//
//      Do not assign m_aw_req's fields after randomising. The other fields were solved against
//      the values they had, so a later overwrite can leave the request illegal. AWLEN is the
//      clearest case: m_len feeds both the 4kB-crossing and the wrapping-burst constraints in
//      axi_txn_request_item, which is why the beat count reaches it through a constraint rather
//      than being patched in afterwards.
//   - Optionally configure m_b_accept to control bready timing (see axi_mgr_write_response_seq).
//      Its m_use_fixed_*/m_fixed_* values are copied to the accept. m_b_accept is deliberately not
//      rand, so it can be configured before or after randomising this sequence without being
//      overwritten either way.
//   - start(null). Being a virtual sequence, it drives the AW, W and B sequencers itself and does
//      not need a sequencer of its own.
//
// As a backstop, body() re-checks the request against the AXI legality constraints in
// axi_txn_request_item, and checks AWLEN against the beat count, raising a uvm_error if either
// does not hold.
//
// On completion, rsp is an axi_fixed_write_rsp_item where:
//   - m_aw_status is the status of the AW transfer. Its m_sending_complete is 0 if a reset
//     stopped the request being sent.
//   - m_w_status is the same for the W beats.
//   - m_write_response is the B response. AXI returns exactly one B per burst however many beats
//     it had, so there is a single response here rather than one per beat.
//
// If a reset happens part-way through, the sequence still completes and still populates rsp, but
// m_write_response is left null. A caller that cares should check it alongside the
// m_sending_complete flags on m_aw_status and m_w_status.

class axi_mgr_write_burst_vseq extends uvm_sequence#(uvm_sequence_item, axi_fixed_write_rsp_item);
  `uvm_object_utils(axi_mgr_write_burst_vseq)

  // The write response router. Set this by calling set_write_response_router before starting.
  local axi_response_router        m_write_response_router;

  // Sequencers for AW, W and B. Set these by calling set_sequencers before starting.
  local write_request_sequencer_t  m_write_request_sequencer;
  local write_data_sequencer_t     m_write_data_sequencer;
  local write_response_sequencer_t m_write_response_sequencer;

  // The AW request to send. Randomised as part of this sequence: to direct the burst, constrain
  // these fields in the sequence's randomize() call rather than assigning them afterwards. AWLEN
  // follows the supplied W beats through len_matches_data_c.
  rand axi_txn_request_item m_aw_req;

  // Tie randomised length to the number of supplied W beats. Set m_data_items before randomize().
  constraint len_matches_data_c {
    m_data_items.size() > 0 -> m_aw_req.m_len == m_data_items.size() - 1;
  }

  // The write data beats, in order; one item per beat. AWLEN is constrained to equal
  // m_data_items.size()-1.
  axi_write_data_item m_data_items[$];

  // B-channel accept (backpressure) template. Configure its m_use_fixed_*/m_fixed_* values to
  // control bready timing: pinned fields take the fixed value; unpinned fields are randomised.
  axi_mgr_write_response_seq m_b_accept;

  extern function new(string name="");
  extern task body();

  // Set the write response router
  extern function void set_write_response_router(axi_response_router router);

  // Set sequencers for the AW, W and B channels
  extern function void set_sequencers(write_request_sequencer_t  write_request_sequencer,
                                      write_data_sequencer_t     write_data_sequencer,
                                      write_response_sequencer_t write_response_sequencer);
endclass

function axi_mgr_write_burst_vseq::new(string name="");
  super.new(name);
  m_aw_req = axi_txn_request_item::type_id::create("m_aw_req");
  m_b_accept = axi_mgr_write_response_seq::type_id::create("m_b_accept");
endfunction

task axi_mgr_write_burst_vseq::body();
  axi_mgr_txn_request_seq        aw_seq;
  axi_mgr_write_listed_data_seq  w_seq;
  axi_mgr_write_response_seq     b_seq;
  uvm_sequence_item              write_response_item;
  axi_write_response_item        write_response;

  if (m_write_response_router == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because there is no write response router.")
  end
  if (m_write_request_sequencer == null ||
      m_write_data_sequencer == null ||
      m_write_response_sequencer == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because sequencers are not all set.")
  end
  if (m_data_items.size() == 0) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence: m_data_items is empty.")
  end

  // Check AWLEN matches the beats we are about to send. This holds by construction when
  // m_data_items was populated before this sequence was randomised, which is what
  // len_matches_data_c is for; patching m_len here instead would invalidate the fields that were
  // solved against it.
  if (m_data_items.size() != int'(m_aw_req.m_len) + 1) begin
    `uvm_fatal(get_full_name(),
               $sformatf({"AWLEN is %0d (so %0d beats) but m_data_items holds %0d. Populate ",
                          "m_data_items before randomising this sequence."},
                         m_aw_req.m_len, m_aw_req.m_len + 1, m_data_items.size()))
  end

  // Check the request is AXI-legal.
  if (!m_aw_req.randomize(null)) begin
    `uvm_error(get_full_name(),
               "AW request violates AXI legality constraints (see axi_txn_request_item)")
  end

  // Construct the write request sequence (AW), handing it m_aw_req to send verbatim.
  aw_seq = axi_mgr_txn_request_seq::type_id::create("aw_seq");
  aw_seq.m_req = m_aw_req;

  // Construct the write data sequence (W): one beat per item in m_data_items.
  w_seq = axi_mgr_write_listed_data_seq::type_id::create("w_seq");
  w_seq.m_items = m_data_items;
  if (!w_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize w_seq.")
  end

  // Construct the sequence that receives the write response (B). It might or might not match our
  // ID; the router sorts that out by ID.
  if (!$cast(b_seq, m_b_accept.clone())) begin
    `uvm_fatal(get_full_name(), "Clone of m_b_accept is not an axi_mgr_write_response_seq.")
  end

  // The clone carries the template's name, so rename it.
  b_seq.set_name("b_seq");
  if (!b_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize b_seq.")
  end

  // Consume a write response in the background and hand it to the router.
  fork begin
    b_seq.start(m_write_response_sequencer);
    if (b_seq.rsp != null) begin
      m_write_response_router.on_response(b_seq.rsp.m_id, b_seq.rsp);
    end
  end join_none

  // Run AW and W, and wait for our B response.
  fork
    aw_seq.start(m_write_request_sequencer);
    w_seq.start(m_write_data_sequencer);
    m_write_response_router.wait_for_response(m_aw_req.m_id, write_response_item);
  join

  // write_response_item is null on reset; otherwise downcast to the concrete type.
  if (write_response_item != null && !$cast(write_response, write_response_item))
    `uvm_fatal(get_full_name(), "wait_for_response returned unexpected item type")

  rsp = axi_fixed_write_rsp_item::type_id::create("rsp");
  rsp.m_aw_status      = aw_seq.rsp;
  rsp.m_w_status       = w_seq.rsp;
  rsp.m_write_response = write_response;
endtask

function void axi_mgr_write_burst_vseq::set_write_response_router(axi_response_router router);
  if (router == null) `uvm_fatal(get_full_name(), "Router is null.")
  m_write_response_router = router;
endfunction

function void axi_mgr_write_burst_vseq::set_sequencers(
    write_request_sequencer_t  write_request_sequencer,
    write_data_sequencer_t     write_data_sequencer,
    write_response_sequencer_t write_response_sequencer);
  if (write_request_sequencer == null)  `uvm_fatal(get_full_name(), "No write_request_sequencer.")
  if (write_data_sequencer == null)     `uvm_fatal(get_full_name(), "No write_data_sequencer.")
  if (write_response_sequencer == null) `uvm_fatal(get_full_name(), "No write_response_sequencer.")

  m_write_request_sequencer  = write_request_sequencer;
  m_write_data_sequencer     = write_data_sequencer;
  m_write_response_sequencer = write_response_sequencer;
endfunction
