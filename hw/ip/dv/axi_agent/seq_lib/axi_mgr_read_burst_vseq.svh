// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A virtual sequence that sends a single AXI read burst of arbitrary length and collects every
// returned beat.

class axi_mgr_read_burst_vseq extends uvm_sequence#(uvm_sequence_item, axi_fixed_read_rsp_item);
  `uvm_object_utils(axi_mgr_read_burst_vseq)

  // Read response router. Set by calling set_read_response_router before starting.
  local axi_response_router       m_read_response_router;

  // Sequencers for AR and R. Set by calling set_sequencers before starting.
  local read_request_sequencer_t  m_read_request_sequencer;
  local read_data_sequencer_t     m_read_data_sequencer;

  // The AR request to send. Randomised as part of this sequence. For a
  // purely directed burst, set m_ar_req fields directly before start().
  rand axi_txn_request_item m_ar_req;

  // R-channel accept (backpressure) template. Configure its m_use_fixed_*/m_fixed_* pins to control
  // rready timing: pinned fields take the fixed value on every beat; unpinned fields are randomised
  // independently per beat (the default).
  axi_mgr_read_data_seq m_r_accept;

  // The read data beats that came back, in beat order. Populated by body().
  axi_read_data_item m_read_beats[$];

  extern function new(string name="");
  extern task body();

  // Accept one R beat: run the given read-data seq and deposit its response into the router.
  // Spawned once per beat by body().
  extern local task accept_one_beat(axi_mgr_read_data_seq r_seq);

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
  int unsigned            n_beats = 32'(m_ar_req.m_len) + 1;

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

  // Send the read request (AR): hand m_ar_req to the request seq to send verbatim.
  ar_seq = axi_mgr_txn_request_seq::type_id::create("ar_seq");
  ar_seq.m_req = m_ar_req;

  // Accept every R beat, all inside one isolation fork so no accept process outlives this task.
  // Each accept is spawned up front (so rready is asserted before data arrives) and deposits its
  // beat into the router keyed by RID via accept_one_beat(). Because beats arrive in order, the
  // router's per-ID FIFO preserves beat order regardless of sequencer arbitration order.
  m_read_beats.delete();
  fork : isolation_fork
    begin
      // Spawn one accept process per beat, before AR is sent.
      for (int unsigned i = 0; i < n_beats; i++) begin
        automatic axi_mgr_read_data_seq r_seq =
          axi_mgr_read_data_seq::type_id::create($sformatf("r_seq_%0d", i));
        r_seq.m_use_fixed_ready_without_valid_pct = m_r_accept.m_use_fixed_ready_without_valid_pct;
        r_seq.m_fixed_ready_without_valid_pct     = m_r_accept.m_fixed_ready_without_valid_pct;
        r_seq.m_use_fixed_valid_to_ready_delay    = m_r_accept.m_use_fixed_valid_to_ready_delay;
        r_seq.m_fixed_valid_to_ready_delay        = m_r_accept.m_fixed_valid_to_ready_delay;
        if (!r_seq.randomize()) begin
          `uvm_fatal(get_full_name(), "Failed to randomize r_seq.")
        end
        fork
          accept_one_beat(r_seq);
        join_none
      end

      // Send AR and drain the router for our n_beats responses, concurrently with the accepts.
      fork
        ar_seq.start(m_read_request_sequencer);
        begin
          for (int unsigned i = 0; i < n_beats; i++) begin
            uvm_sequence_item  read_data_item;
            axi_read_data_item read_data;
            m_read_response_router.wait_for_response(m_ar_req.m_id, read_data_item);
            if (read_data_item == null) break;  // reset
            if (!$cast(read_data, read_data_item))
              `uvm_fatal(get_full_name(), "wait_for_response returned unexpected item type")
            m_read_beats.push_back(read_data);
          end
        end
      join

      wait fork;
    end
  join

  rsp = axi_fixed_read_rsp_item::type_id::create("rsp");
  rsp.m_ar_status = ar_seq.rsp;
  rsp.m_read_data = (m_read_beats.size() > 0) ? m_read_beats[0] : null;
endtask

task axi_mgr_read_burst_vseq::accept_one_beat(axi_mgr_read_data_seq r_seq);
  r_seq.start(m_read_data_sequencer);
  if (r_seq.rsp != null) begin
    m_read_response_router.on_response(r_seq.rsp.m_id, r_seq.rsp);
  end
endtask : accept_one_beat

function void axi_mgr_read_burst_vseq::set_read_response_router(axi_response_router router);
  if (router == null) `uvm_fatal(get_full_name(), "Router is null.")
  m_read_response_router = router;
endfunction

function void axi_mgr_read_burst_vseq::set_sequencers(read_request_sequencer_t  read_request_sequencer,
                                          read_data_sequencer_t     read_data_sequencer);
  if (read_request_sequencer == null)  `uvm_fatal(get_full_name(), "No read_request_sequencer.")
  if (read_data_sequencer == null)     `uvm_fatal(get_full_name(), "No read_data_sequencer.")

  m_read_request_sequencer  = read_request_sequencer;
  m_read_data_sequencer     = read_data_sequencer;
endfunction
