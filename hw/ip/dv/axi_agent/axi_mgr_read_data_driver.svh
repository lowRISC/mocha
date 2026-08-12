// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A driver for axi_read_data_if, used when the testbench is acting as an AXI Manager that is
// accepting read data (responding to read requests).

class axi_mgr_read_data_driver extends dv_base_driver#(.ITEM_T     (axi_response_accept_item),
                                                       .CFG_T      (axi_agent_cfg),
                                                       .RSP_ITEM_T (uvm_sequence_item));
  `uvm_component_utils(axi_mgr_read_data_driver)

  local virtual axi_read_data_if m_vif;

  extern function new(string name, uvm_component parent);

  // Pick up the channel interface from cfg and check that it is one we can drive.
  extern function void connect_phase(uvm_phase phase);

  // Run forever, consuming and driving items from seq_item_port
  extern virtual task get_and_drive();

  // Clear rready when a reset starts. Called by dv_base_driver::reset_signals, which tracks the
  // cfg.in_reset flag maintained by axi_reset_monitor.
  extern virtual task on_enter_reset();

  // A task that drives the axi_response_accept_item in the req class variable
  //
  // This returns when the item is driven, but returns early if there is a reset. When an item is
  // driven, the data that was read is sampled and is used to populate an axi_read_data_item which
  // is returned in the response output argument.
  //
  // If there is a reset (causing the task to return early), the rsp class variable is populated
  // with an axi_status_item with m_sending_complete=0. That way, the driver always returns a
  // sequence item of some sort to the sequencer, which can pass that back to the sequence (which
  // can then handle the response).
  extern local task drive_req();
endclass

function axi_mgr_read_data_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction

function void axi_mgr_read_data_driver::connect_phase(uvm_phase phase);
  super.connect_phase(phase);

  if (cfg == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: cfg is null.")
    return;
  end

  if (cfg.read_data_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: vif is null.")
    return;
  end

  if (cfg.read_data_vif.if_mode != dv_utils_pkg::Host) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Host.",
                         cfg.read_data_vif.if_mode.name()))
    return;
  end

  m_vif = cfg.read_data_vif;
endfunction

task axi_mgr_read_data_driver::get_and_drive();
  forever begin
    seq_item_port.get_next_item(req);
    drive_req();
    rsp.set_id_info(req);
    seq_item_port.item_done(rsp);
  end
endtask

task axi_mgr_read_data_driver::on_enter_reset();
  m_vif.mgr_cb.rready <= 1'b0;
endtask

task axi_mgr_read_data_driver::drive_req();
  // Set *some* response, which is the default axi_status_item (with m_sending_complete=0). This
  // will be overridden by an axi_read_data_item if we finish reading data.
  rsp = axi_status_item::type_id::create("rsp");

  // If we are currently in reset, there is nothing to do. This check avoids a possible race if
  // reset is asserted at the same time as the response appears: we don't want to set rready after
  // on_enter_reset has cleared it.
  if (cfg.in_reset) return;

  fork : isolation_fork begin
    fork
      wait(cfg.in_reset);
      begin
        axi_read_data_item read_data_item;
        // Cycles elapsed since rvalid was first seen; zero means it has not been seen yet.
        int unsigned delay = 0;

        // Drive rready and watch for the actual transfer. We track the value we drive in
        // rather than reading it back from the clocking block, and we sample on that exact
        // handshake edge. This is what makes the accept protocol-correct:
        //   * a speculative rready (asserted before rvalid via ready_without_valid_pct) that
        //     catches the beat is detected and sampled, instead of consuming the beat unsampled
        //   * two accepts running back-to-back (no clock edge between sequence items) cannot
        //     re-sample the same beat, because each iteration advances a clock before checking.
        forever begin
          // the value we drive onto rready this cycle
          bit rready;

          if (delay == 0) begin
            // Before rvalid: optionally assert rready speculatively.
            rready = ($urandom_range(0, 99) < req.m_ready_without_valid_pct);
          end else begin
            // After rvalid: hold rready low for valid_to_ready_delay cycles, then assert it.
            rready = (delay >= req.m_valid_to_ready_delay);
          end

          m_vif.mgr_cb.rready <= rready;
          @(m_vif.mgr_cb);

          if (m_vif.mgr_cb.rvalid === 1'b1) begin
            if (rready) break;  // rvalid && rready on this edge: beat transferred
            delay++;            // counts the cycle just elapsed, including the first rvalid one
          end
        end

        // The beat transferred on the edge that just finished: sample the value.
        read_data_item = axi_read_data_item::type_id::create("read_data_item");
        read_data_item.m_id   = m_vif.mgr_cb.rid;
        read_data_item.m_data = m_vif.mgr_cb.rdata;
        read_data_item.m_resp = axi_read_data_item::rresp_e'(m_vif.mgr_cb.rresp);
        read_data_item.m_last = m_vif.mgr_cb.rlast;
        read_data_item.m_user = m_vif.mgr_cb.ruser;

        rsp = read_data_item;

        // Deassert rready. If the next accept follows immediately, its first iteration re-drives
        // rready before the next clock edge, so consecutive beats are still accepted seamlessly.
        m_vif.mgr_cb.rready <= 1'b0;
      end
    join_any
    disable fork;
  end join
endtask
