// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_virtual_sequencer extends uvm_sequencer;
  `uvm_component_utils(top_chip_dv_virtual_sequencer)

  // Handles for ease of operation
  top_chip_dv_env_cfg cfg;
  top_chip_dv_env_cov cov;

  mem_bkdr_util mem_bkdr_util_h[chip_mem_e];

  // Handles to specific interface agent sequencers. Used by some virtual
  // sequences to drive RX (to-chip) items.
  uart_sequencer uart_sqr;
  i2c_sequencer  i2c_sqr;

  // FIFOs for monitor output. Used by some virtual sequences to check
  // TX (from-chip) items.
  uvm_tlm_analysis_fifo #(uart_item) uart_tx_fifo;

  // Standard SV/UVM methods
  extern function new(string name = "", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
endclass : top_chip_dv_virtual_sequencer


function top_chip_dv_virtual_sequencer::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void top_chip_dv_virtual_sequencer::build_phase(uvm_phase phase);
  super.build_phase(phase);
  // Construct monitor output FIFOs
  uart_tx_fifo = new("uart_tx_fifo", this);
endfunction : build_phase
