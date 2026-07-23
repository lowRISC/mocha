// Copyright lowRISC contributors
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A driver for axi_read_data_if, used when the testbench is acting as an AXI Manager that is
// accepting read data (responding to read requests).

class axi_mgr_read_data_driver extends uvm_driver#(axi_response_accept_item, uvm_sequence_item);
  `uvm_component_utils(axi_mgr_read_data_driver)

  local virtual axi_read_data_if m_vif;
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
  extern function void set_vif(virtual axi_read_data_if vif);

  // Set the shared clock/reset interface. This must be called before run_phase.
  extern function void set_clk_rst_vif(virtual clk_rst_if vif);

  // Run forever, consuming and driving items from seq_item_port
  extern local task get_and_drive();

  // Run forever, tracking rst_ni and maintaining an in_reset class variable. Clears rready in the
  // clocking block when a reset is seen.
  extern local task monitor_reset();

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

function void axi_mgr_read_data_driver::set_vif(virtual axi_read_data_if vif);
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

function void axi_mgr_read_data_driver::set_clk_rst_vif(virtual clk_rst_if vif);
  m_clk_rst_vif = vif;
endfunction

task axi_mgr_read_data_driver::run_phase(uvm_phase phase);
  if (m_vif == null || m_clk_rst_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: vif is null.")
    return;
  end

  // Clear rready (we only wish to assert that we are ready if we are driving an item)
  m_vif.mgr_cb.rready <= 1'b0;

  fork
    get_and_drive();
    monitor_reset();
  join
endtask

task axi_mgr_read_data_driver::get_and_drive();
  forever begin
    seq_item_port.get_next_item(req);
    drive_req();
    rsp.set_id_info(req);
    seq_item_port.item_done(rsp);
  end
endtask

task axi_mgr_read_data_driver::monitor_reset();
  wait(!$isunknown(m_clk_rst_vif.rst_n));
  m_in_reset = !m_clk_rst_vif.rst_n;
  forever begin
    wait (m_clk_rst_vif.rst_n);
    m_in_reset = 0;
    wait (!m_clk_rst_vif.rst_n);
    m_in_reset = 1;
    m_vif.mgr_cb.rready <= 1'b0;
  end
endtask

task axi_mgr_read_data_driver::drive_req();
  // Set *some* response, which is the default axi_status_item (with m_sending_complete=0). This
  // will be overridden by an axi_read_data_item if we finish reading data.
  rsp = axi_status_item::type_id::create("rsp");

  // If we are currently in reset, there is nothing to do. This check avoids a possible race if
  // reset is asserted at the same time as the response appears: we don't want to set rready after
  // monitor_reset has cleared it.
  if (m_in_reset) return;

  fork : isolation_fork begin
    fork
      wait(m_in_reset);
      begin
        axi_read_data_item read_data_item;
        bit          valid_seen = 1'b0; // rvalid has been observed at least once
        int unsigned delay      = 0;    // cycles counted since rvalid was first seen

        // Drive rready and watch for the actual transfer. We track the rready we drive in rready
        // rather than reading it back from the clocking block, and we sample on that exact
        // handshake edge. This is what makes the accept protocol-correct:
        //   * a speculative rready (asserted before rvalid via ready_without_valid_pct) that
        //     catches the beat is detected and sampled, instead of consuming the beat unsampled
        //   * two accepts running back-to-back (no clock edge between sequence items) cannot
        //     re-sample the same beat, because each iteration advances a clock before checking.
        forever begin
          // the value we drive onto rready this cycle
          bit rready;

          if (!valid_seen) begin
            // Before rvalid: optionally assert rready speculatively.
            rready = ($urandom_range(0, 99) < req.m_ready_without_valid_pct);
          end else begin
            // After rvalid: hold rready low for valid_to_ready_delay cycles, then assert it.
            rready = (delay >= req.m_valid_to_ready_delay);
          end

          m_vif.mgr_cb.rready <= rready;
          @(m_vif.mgr_cb);

          if (m_vif.mgr_cb.rvalid === 1'b1) begin
            if (rready) break;                   // rvalid && rready on this edge: beat transferred
            if (!valid_seen) valid_seen = 1'b1;  // first rvalid: start the valid-to-ready countdown
            else             delay++;
          end
        end

        // The beat transferred on the edge we just broke out of: sample it.
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
