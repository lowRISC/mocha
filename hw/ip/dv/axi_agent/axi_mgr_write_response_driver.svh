// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A driver for axi_write_response_if, used when the testbench is acting as an AXI Manager that is
// accepting write responses.
//
// This will normally send an axi_write_response_item as a response to the sequencer. If sending the
// request is interrupted by a reset, this will instead return a axi_status_item with
// m_sending_complete == 0.

class axi_mgr_write_response_driver extends uvm_driver#(axi_response_accept_item,
                                                        uvm_sequence_item);
  `uvm_component_utils(axi_mgr_write_response_driver)

  local virtual axi_write_response_if m_vif;
  local virtual clk_rst_if m_clk_rst_vif;

  // True if the interface is currently in reset. Maintained by monitor_reset().
  //
  // At the very start of the simulation, rst_ni might be 'x or 'z. This isn't considered a "proper"
  // reset: in_reset can only be asserted by seeing rst_ni === 0 (and then cleared by seeing it
  // become 1).
  local bit m_in_reset;

  extern function new(string name, uvm_component parent);
  extern virtual task run_phase(uvm_phase phase);

  // Set m_vif. This must be called before run_phase.
  extern function void set_vif(virtual axi_write_response_if vif);

  // Set the shared clock/reset interface. This must be called before run_phase.
  extern function void set_clk_rst_vif(virtual clk_rst_if vif);

  // Run forever, consuming and driving items from seq_item_port
  extern local task get_and_drive();

  // Run forever, tracking rst_ni and maintaining an in_reset class variable. Clears bready in the
  // clocking block when a reset is seen.
  extern local task monitor_reset();

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

function void axi_mgr_write_response_driver::set_vif(virtual axi_write_response_if vif);
  if (m_vif != null) begin
    `uvm_fatal(get_full_name(), "Cannot call set_vif: there is already an interface.")
    return;
  end

  if (vif.if_mode != dv_utils_pkg::Host) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Host.",
                         vif.if_mode.name()))
    return;
  end

  m_vif = vif;
endfunction

function void axi_mgr_write_response_driver::set_clk_rst_vif(virtual clk_rst_if vif);
  m_clk_rst_vif = vif;
endfunction

task axi_mgr_write_response_driver::run_phase(uvm_phase phase);
  if (m_vif == null || m_clk_rst_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: vif is null.")
    return;
  end

  // Clear bready (we only wish to assert that we are ready if we are driving an item)
  m_vif.mgr_cb.bready <= 1'b0;

  fork
    get_and_drive();
    monitor_reset();
  join
endtask

task axi_mgr_write_response_driver::get_and_drive();
  forever begin
    seq_item_port.get_next_item(req);
    drive_req();
    rsp.set_id_info(req);
    seq_item_port.item_done(rsp);
  end
endtask

task axi_mgr_write_response_driver::monitor_reset();
  wait(!$isunknown(m_clk_rst_vif.rst_n));
  m_in_reset = !m_clk_rst_vif.rst_n;
  forever begin
    wait (m_clk_rst_vif.rst_n);
    m_in_reset = 0;
    wait (!m_clk_rst_vif.rst_n);
    m_in_reset = 1;
    m_vif.mgr_cb.bready <= 1'b0;
  end
endtask

task axi_mgr_write_response_driver::drive_req();
  // Create a default response, which is an axi_status_item with its default state
  // (m_sending_complete = 0). This will be overridden with an axi_write_response_item if a response
  // is read.
  rsp = axi_status_item::type_id::create("rsp");

  // If we are currently in reset, there is nothing to do. This check avoids a possible race if
  // reset is asserted at the same time as the response appears: we don't want to set bready after
  // monitor_reset has cleared it.
  if (m_in_reset) begin
    return;
  end

  fork : isolation_fork begin
    fork
      wait(m_in_reset);
      begin
        axi_write_response_item response;
        bit          valid_seen = 1'b0; // bvalid has been observed at least once
        int unsigned delay      = 0;    // cycles counted since bvalid was first seen

        // Drive bready and watch for the actual transfer. We track the bready we drive in bready
	      // rather than reading it back from the clocking block, and we sample on that exact
        // handshake edge. This is what makes the accept protocol-correct:
        //   * a speculative bready (asserted before bvalid via ready_without_valid_pct) that
        //     catches the response is detected and sampled, instead of consuming the
        //     response unsampled
        //   * two accepts running back-to-back (no clock edge between sequence items) cannot
        //     re-sample the same response, because each iteration advances a clock before checking.
        forever begin
          // the value we drive onto bready this cycle
          bit bready;

          if (!valid_seen) begin
            // Before bvalid: optionally assert bready speculatively.
            bready = ($urandom_range(0, 99) < req.m_ready_without_valid_pct);
          end else begin
            // After bvalid: hold bready low for valid_to_ready_delay cycles, then assert it.
            bready = (delay >= req.m_valid_to_ready_delay);
          end

          m_vif.mgr_cb.bready <= bready;
          @(m_vif.mgr_cb);

          if (m_vif.mgr_cb.bvalid === 1'b1) begin
            if (bready) break;                   // bvalid && bready on this edge: response accepted
            if (!valid_seen) valid_seen = 1'b1;  // first bvalid: start the valid-to-ready countdown
            else             delay++;
          end
        end

        // The response transferred on the edge we just broke out of: sample it.
        response = axi_write_response_item::type_id::create("response");
        response.m_id   = m_vif.mgr_cb.bid;
        response.m_resp = axi_write_response_item::bresp_e'(m_vif.mgr_cb.bresp);
        response.m_user = m_vif.mgr_cb.buser;

        // Set rsp, which will pass the response back to the sequencer.
        rsp = response;

        // Deassert bready. If the next accept follows immediately, its first iteration re-drives
        // bready before the next clock edge, so consecutive responses are still accepted seamlessly.
        m_vif.mgr_cb.bready <= 1'b0;
      end
    join_any
    disable fork;
  end join
endtask
