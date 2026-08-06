// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A driver for axi_write_response_if, used when the testbench is acting as an AXI Manager that is
// accepting write responses.
//
// This will normally send an axi_write_response_item as a response to the sequencer. If sending the
// request is interrupted by a reset, this will instead return a axi_status_item with
// m_sending_complete == 0.

class axi_mgr_write_response_driver extends dv_base_driver#(.ITEM_T     (axi_response_accept_item),
                                                            .CFG_T      (axi_agent_cfg),
                                                            .RSP_ITEM_T (uvm_sequence_item));
  `uvm_component_utils(axi_mgr_write_response_driver)

  local virtual axi_write_response_if m_vif;

  extern function new(string name, uvm_component parent);

  // Pick up the channel interface from cfg and check that it is one we can drive.
  extern function void connect_phase(uvm_phase phase);

  // Run forever, consuming and driving items from seq_item_port
  extern virtual task get_and_drive();

  // Clear bready when a reset starts.
  extern virtual task on_enter_reset();

  // A task that drives the axi_response_accept_item in the req class variable
  //
  // This returns when the response has been accepted, setting rsp to be an axi_write_response_item
  // with its contents. If there is a reset, the task returns early and sets rsp to be an
  // axi_status_item with m_sending_complete == 0.
  extern local task drive_req();
endclass

function axi_mgr_write_response_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction

function void axi_mgr_write_response_driver::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  if (cfg == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: cfg is null.")
    return;
  end

  if (cfg.write_response_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: cfg.write_response_vif is null.")
    return;
  end

  if (cfg.write_response_vif.if_mode != dv_utils_pkg::Host) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Host.",
                         cfg.write_response_vif.if_mode.name()))
    return;
  end

  m_vif = cfg.write_response_vif;
endfunction

task axi_mgr_write_response_driver::get_and_drive();
  forever begin
    seq_item_port.get_next_item(req);
    drive_req();
    rsp.set_id_info(req);
    seq_item_port.item_done(rsp);
  end
endtask

task axi_mgr_write_response_driver::on_enter_reset();
  m_vif.mgr_cb.bready <= 1'b0;
endtask

task axi_mgr_write_response_driver::drive_req();
  // Create a default response, which is an axi_status_item with its default state
  // (m_sending_complete = 0). This will be overridden with an axi_write_response_item if a response
  // is read.
  rsp = axi_status_item::type_id::create("rsp");

  // If we are currently in reset, there is nothing to do. This check avoids a possible race if
  // reset is asserted at the same time as the response appears: we don't want to set bready after
  // on_enter_reset has cleared it.
  if (cfg.in_reset) begin
    return;
  end

  fork : isolation_fork begin
    fork
      wait(cfg.in_reset);
      begin
        axi_write_response_item response;
        // Cycles elapsed since bvalid was first seen; zero means it has not been seen yet.
        int unsigned delay = 0;

        // Drive bready and watch for the actual transfer. We track the value we drive in
        // rather than reading it back from the clocking block, and we sample on that exact
        // handshake edge. This is what makes the accept protocol correct:
        //   * a speculative bready (asserted before bvalid via ready_without_valid_pct) that
        //     catches the response is detected and sampled, instead of consuming the
        //     response unsampled
        //   * two accepts running back-to-back (no clock edge between sequence items) cannot
        //     re-sample the same response, because each iteration advances a clock before checking.
        forever begin
          // the value we drive onto bready this cycle
          bit bready;

          if (delay == 0) begin
            // Before bvalid: optionally assert bready speculatively.
            bready = ($urandom_range(0, 99) < req.m_ready_without_valid_pct);
          end else begin
            // After bvalid: hold bready low for valid_to_ready_delay cycles, then assert it.
            bready = (delay >= req.m_valid_to_ready_delay);
          end

          m_vif.mgr_cb.bready <= bready;
          @(m_vif.mgr_cb);

          if (m_vif.mgr_cb.bvalid === 1'b1) begin
            if (bready) break;  // bvalid && bready on this edge: response accepted
            delay++;            // count the cycle just elapsed, including the first bvalid one
          end
        end

        // The response has just transferred: sample it.
        response = axi_write_response_item::type_id::create("response");
        response.m_id   = m_vif.mgr_cb.bid;
        response.m_resp = axi_write_response_item::bresp_e'(m_vif.mgr_cb.bresp);
        response.m_user = m_vif.mgr_cb.buser;

        // Set rsp, which will pass the response back to the sequencer.
        rsp = response;

        // Deassert bready. If the next accept follows immediately, its first iteration re-drives
        // bready before the next clock edge, so consecutive responses are still accepted
        // seamlessly.
        m_vif.mgr_cb.bready <= 1'b0;
      end
    join_any
    disable fork;
  end join
endtask
