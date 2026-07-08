// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A virtual sequence that sends a single AXI read burst of arbitrary length and collects every
// returned beat.
//
// To use it:
//
//   - Create it, then call set_sequencers() and set_read_response_router().
//   - Choose the request by randomising this sequence. m_ar_req is rand, so a plain randomize()
//      picks a legal burst. To direct it, constrain the fields that matter in the same call:
//
//        if (!vseq.randomize() with { m_ar_req.m_addr == 'h1000;
//                                     m_ar_req.m_len  == 3; }) ...
//
//      Do not assign m_ar_req's fields after randomising. The other fields were solved against
//      the values they had, and axi_txn_request_item relates them (m_len, m_size, m_addr and
//      m_burst all appear together in its legality constraints), so a later overwrite can leave
//      the request illegal. The m_ar_req.m_len variable controls ARLEN and the burst has ARLEN+1
//      beats. 
//   - Optionally configure m_r_accept to control rready timing (see axi_mgr_read_data_seq). Its
//      m_use_fixed_*/m_fixed_* values are copied to every beat; unpinned fields are randomised
//      independently per beat. m_r_accept is deliberately not rand, so it can be configured
//      before or after randomising this sequence without being overwritten either way.
//   - start(null). Being a virtual sequence, it drives the AR and R sequencers itself and does
//      not need a sequencer of its own.
//
// As a backstop, body() re-checks the request against the AXI legality constraints in
// axi_txn_request_item and raises a uvm_error if they do not hold.
//
// On completion, rsp is an axi_fixed_read_rsp_item where:
//   - m_ar_status is the status of the AR transfer. Its m_sending_complete is 0 if a reset
//     stopped the request being sent.
//   - m_read_data holds the beats that arrived, in beat order. The same beats are also left in
//     the public m_read_beats queue.
//
// If a reset happens part-way through, the sequence still completes and still populates rsp, but
// m_read_data is short: it holds only the beats that had already arrived, possibly none at all. A
// caller that cares should check m_ar_status.m_sending_complete and m_read_data.size() rather than
// assuming m_len + 1 beats came back.

class axi_mgr_read_burst_vseq extends uvm_sequence#(uvm_sequence_item, axi_fixed_read_rsp_item);
  `uvm_object_utils(axi_mgr_read_burst_vseq)

  // Read response router. Set this by calling set_read_response_router before starting.
  local axi_response_router       m_read_response_router;

  // Sequencers for AR and R. Set this by calling set_sequencers before starting.
  local read_request_sequencer_t  m_read_request_sequencer;
  local read_data_sequencer_t     m_read_data_sequencer;

  // The AR request to send. Randomised as part of this sequence: to direct the burst, constrain
  // these fields in the sequence's randomize() call rather than assigning them afterwards.
  rand axi_txn_request_item m_ar_req;

  // R-channel accept (backpressure) template. Configure its m_use_fixed_*/m_fixed_* values to 
  // control rready timing: pinned fields take the fixed value on every beat; unpinned fields are
  // randomised independently per beat (the default).
  axi_mgr_read_data_seq m_r_accept;

  // The read data beats that came back, in beat order. Populated by body().
  axi_read_data_item m_read_beats[$];

  extern function new(string name="");
  extern task body();

  // Accept one R beat: build a read-data seq from the m_r_accept template, run it, and deposit its
  // response into the router. Spawned once per beat by body(); beat_num only names the seq.
  extern local task accept_one_beat(int unsigned beat_num);

  // Take n_beats responses for our AR channel's ID back out of the router, in beat order,
  // appending each to m_read_beats. Returns early if a reset makes the router hand back a null
  // item.
  extern local task collect_read_beats(int unsigned n_beats);

  // Set the read response router
  extern function void set_read_response_router(axi_response_router router);

  // Set sequencers for the AR and R channels
  extern function void set_sequencers(read_request_sequencer_t  read_request_sequencer,
                                      read_data_sequencer_t     read_data_sequencer);
endclass

function axi_mgr_read_burst_vseq::new(string name="");
  super.new(name);
  m_ar_req = axi_txn_request_item::type_id::create("m_ar_req");
  m_r_accept = axi_mgr_read_data_seq::type_id::create("m_r_accept");
endfunction

task axi_mgr_read_burst_vseq::body();
  axi_mgr_txn_request_seq ar_seq;
  int unsigned            n_beats = m_ar_req.m_len + 1;

  if (m_read_response_router == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because there is no read response router.")
  end
  if (m_read_request_sequencer == null || m_read_data_sequencer == null) begin
    `uvm_fatal(get_full_name(), "Cannot run sequence because sequencers are not both set.")
  end

  // Check the request is AXI-legal.
  if (!m_ar_req.randomize(null)) begin
    `uvm_error(get_full_name(),
               "AR request violates AXI legality constraints (see axi_txn_request_item)")
  end

  // Construct the read request sequence (AR), handing it m_ar_req to send verbatim.
  ar_seq = axi_mgr_txn_request_seq::type_id::create("ar_seq");
  ar_seq.m_req = m_ar_req;

  // Accept every R beat, all inside one isolation fork so no accept process outlives this task.
  // Each accept is spawned up front (so rready is asserted before data arrives) and deposits its
  // beat into the router keyed by RID via accept_one_beat(). Because beats arrive in order, the
  // router's per-ID FIFO preserves beat order regardless of sequencer arbitration order.

  // A non-empty queue here means this sequence has already been started once.
  if (m_read_beats.size() != 0) begin
    `uvm_error(get_full_name(),
               $sformatf({"m_read_beats already holds %0d beats. Has this sequence ",
                          "been started twice?"}, m_read_beats.size()))
    m_read_beats.delete();
  end

  fork : isolation_fork
    begin
      // Spawn one accept process per beat, before AR is sent.
      for (int unsigned i = 0; i < n_beats; i++) begin
        automatic int unsigned beat_num = i;
        fork
          accept_one_beat(beat_num);
        join_none
      end

      // Send AR and drain the router for our n_beats responses, concurrently with the accepts.
      fork
        ar_seq.start(m_read_request_sequencer);
        collect_read_beats(n_beats);
      join

      // Wait for the per-beat accepts / responses on the R channel. Without this the
      // join_none processes would outlive body().
      wait fork;
    end
  join

  rsp = axi_fixed_read_rsp_item::type_id::create("rsp");
  rsp.m_ar_status = ar_seq.rsp;
  rsp.m_read_data = m_read_beats;   // all beats, in order
endtask

task axi_mgr_read_burst_vseq::accept_one_beat(int unsigned beat_num);
  axi_mgr_read_data_seq r_seq;

  // Clone the template, so this beat picks up its rready timing values.
  if (!$cast(r_seq, m_r_accept.clone())) begin
    `uvm_fatal(get_full_name(), "Clone of m_r_accept is not an axi_mgr_read_data_seq.")
  end
  // The clone carries the template's name, so rename it to say which beat it is.
  r_seq.set_name($sformatf("r_seq_%0d", beat_num));

  if (!r_seq.randomize()) begin
    `uvm_fatal(get_full_name(), "Failed to randomize r_seq.")
  end

  r_seq.start(m_read_data_sequencer);
  if (r_seq.rsp != null) begin
    m_read_response_router.on_response(r_seq.rsp.m_id, r_seq.rsp);
  end
endtask : accept_one_beat

task axi_mgr_read_burst_vseq::collect_read_beats(int unsigned n_beats);
  for (int unsigned i = 0; i < n_beats; i++) begin
    uvm_sequence_item  base_item;
    axi_read_data_item read_data_item;

    m_read_response_router.wait_for_response(m_ar_req.m_id, base_item);
    if (base_item == null) break;  // reset
    if (!$cast(read_data_item, base_item))
      `uvm_fatal(get_full_name(), "wait_for_response returned unexpected item type")

    m_read_beats.push_back(read_data_item);
  end
endtask : collect_read_beats

function void axi_mgr_read_burst_vseq::set_read_response_router(axi_response_router router);
  if (router == null) `uvm_fatal(get_full_name(), "Router is null.")
  m_read_response_router = router;
endfunction

function void
  axi_mgr_read_burst_vseq::set_sequencers(read_request_sequencer_t read_request_sequencer,
                                          read_data_sequencer_t    read_data_sequencer);
  if (read_request_sequencer == null)  `uvm_fatal(get_full_name(), "No read_request_sequencer.")
  if (read_data_sequencer == null)     `uvm_fatal(get_full_name(), "No read_data_sequencer.")

  m_read_request_sequencer  = read_request_sequencer;
  m_read_data_sequencer     = read_data_sequencer;
endfunction
