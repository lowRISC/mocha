// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Run drive_channel while ARESETn is high. Reset kills it, drives idle values with VALID and READY
// low (AMBA AXI H.c A3.1.2), and flushes shared state, so no pre-reset transaction survives. Detect
// handshakes from VALID and READY sampled together through mon_cb, and drive through sub_cb.

class axi_sub_driver_base extends uvm_driver #(uvm_sequence_item);
  `uvm_component_utils(axi_sub_driver_base)

  // Separate steps with NBA regions to make driver scheduling deterministic. AW and W record the
  // edge's writes and data first. AR then records reads after writes take their policies. B and R
  // finally see all transactions made answerable at that edge.
  typedef enum int unsigned {
    StepWrites    = 0,
    StepReads     = 1,
    StepResponses = 2
  } edge_step_e;

  // Configuration and shared state, set with set_cfg()
  protected axi_sub_agent_cfg m_cfg;
  protected axi_sub_state     m_state;

  // Shared clock and reset, set with set_clk_rst_vif()
  protected virtual clk_rst_if m_clk_rst_vif;

  // Idle payload policy (see axi_if::drive_x_when_idle), set with set_drive_x_when_idle()
  protected bit m_drive_x_when_idle = 1'b1;

  // For next_ready: cycles waiting for READY and this transfer's chosen delay
  local int unsigned m_valid_wait;
  local int unsigned m_ready_delay;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern task run_phase(uvm_phase phase);

  // Class specific methods

  // Call before run_phase
  extern function void set_cfg(axi_sub_agent_cfg cfg, axi_sub_state state);

  // Call before run_phase
  extern function void set_clk_rst_vif(virtual clk_rst_if vif);

  // Call before run_phase
  extern function void set_drive_x_when_idle(bit drive_x);

  // Run after each reset release until the next reset
  extern protected virtual task drive_channel();

  // Drive idle values and discard work in progress. Runs in zero time, but clocking-block drives
  // require a task.
  extern protected virtual task drive_idle();

  // Return next cycle's READY. waiting means sampled VALID without READY, and can_accept means room
  // for another transfer.
  extern protected function bit next_ready(axi_sub_ready_cfg ready_cfg, bit waiting,
                                           bit can_accept);

  // Wait for step after a clock edge (each step's work must not block)
  extern protected task wait_for_step(edge_step_e step);
endclass : axi_sub_driver_base


function axi_sub_driver_base::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_sub_driver_base::set_cfg(axi_sub_agent_cfg cfg, axi_sub_state state);
  m_cfg   = cfg;
  m_state = state;
endfunction : set_cfg

function void axi_sub_driver_base::set_clk_rst_vif(virtual clk_rst_if vif);
  m_clk_rst_vif = vif;
endfunction : set_clk_rst_vif

function void axi_sub_driver_base::set_drive_x_when_idle(bit drive_x);
  m_drive_x_when_idle = drive_x;
endfunction : set_drive_x_when_idle

task axi_sub_driver_base::run_phase(uvm_phase phase);
  if (m_cfg == null || m_state == null || m_clk_rst_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive: set_cfg or set_clk_rst_vif was not called.")
  end

  drive_idle();
  forever begin
    wait (m_clk_rst_vif.rst_n === 1'b1);
    fork : isolation_fork
      begin
        fork
          wait (m_clk_rst_vif.rst_n !== 1'b1);
          drive_channel();
        join_any
        disable fork;
      end
    join
    drive_idle();
    m_state.flush();
    m_valid_wait = 0;
  end
endtask : run_phase

task axi_sub_driver_base::drive_channel();
  `uvm_fatal(get_full_name(), "drive_channel is not overridden.")
endtask : drive_channel

task axi_sub_driver_base::drive_idle();
  `uvm_fatal(get_full_name(), "drive_idle is not overridden.")
endtask : drive_idle

function bit axi_sub_driver_base::next_ready(axi_sub_ready_cfg ready_cfg, bit waiting,
                                             bit can_accept);
  bit ready;

  // Count the delay from VALID even while there is no room, so each transfer waits its own delay
  if (waiting) begin
    m_valid_wait++;
    ready = (m_valid_wait > m_ready_delay);
  end else begin
    m_valid_wait  = 0;
    m_ready_delay = $urandom_range(ready_cfg.m_min_valid_to_ready, ready_cfg.m_max_valid_to_ready);
    ready         = ($urandom_range(0, 99) < ready_cfg.m_ready_before_valid_pct);
  end
  return ready && can_accept;
endfunction : next_ready

task axi_sub_driver_base::wait_for_step(edge_step_e step);
  repeat (int'(step)) begin
    uvm_wait_for_nba_region();
  end
endtask : wait_for_step
