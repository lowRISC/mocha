// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

package axi_agent_pkg;
  import uvm_pkg::*;
  import axi_widths_pkg::*;
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  // The possible encodings of the AxBURST signal
  typedef enum bit [AxiBurstWidth-1:0] {
    BurstFixed = 0,
    BurstIncr  = 1,
    BurstWrap  = 2
  } burst_e;

  // AXI4 BRESP and RRESP encodings (AMBA AXI H.c A3.4.5)
  typedef enum bit [AxiRespWidth-1:0] {
    RespOkay   = 0,
    RespExOkay = 1,
    RespSlverr = 2,
    RespDecerr = 3
  } axi_resp_e;

  // Return the address and byte lanes [lower, upper] of zero-based beat n on a bus of bus_bytes
  // bytes, using the AMBA AXI H.c burst equations (A3.4.1, A3.4.2)
  function automatic void axi_beat_lanes(input  bit [AxiMaxAddrWidth-1:0] start_addr,
                                         input  bit [AxiSizeWidth-1:0]    size,
                                         input  bit [AxiLenWidth-1:0]     len,
                                         input  bit [AxiBurstWidth-1:0]   burst,
                                         input  int unsigned              bus_bytes,
                                         input  int unsigned              n,
                                         output bit [AxiMaxAddrWidth-1:0] addr,
                                         output int unsigned              lower_lane,
                                         output int unsigned              upper_lane);
    int unsigned              number_bytes = 1 << size;
    int unsigned              burst_length = int'(len) + 1;
    bit [AxiMaxAddrWidth-1:0] aligned_addr = (start_addr / number_bytes) * number_bytes;
    bit [AxiMaxAddrWidth-1:0] wrap_boundary;

    // Use N = n + 1 for Address_N. Compute WRAP offsets within the region to avoid overflow at the
    // top of the address space.
    if (burst == BurstFixed || n == 0) begin
      addr = start_addr;
    end else if (burst == BurstWrap) begin
      wrap_boundary = (start_addr / (number_bytes * burst_length)) * (number_bytes * burst_length);
      addr = wrap_boundary + (aligned_addr - wrap_boundary + n * number_bytes) %
                             (number_bytes * burst_length);
    end else begin
      addr = aligned_addr + n * number_bytes;
    end

    // An unaligned transfer ends at its aligned container's end. FIXED bursts reuse the first
    // beat's lanes.
    lower_lane = addr % bus_bytes;
    if (addr == (addr / number_bytes) * number_bytes) begin
      upper_lane = lower_lane + number_bytes - 1;
    end else begin
      upper_lane = (aligned_addr % bus_bytes) + number_bytes - 1;
    end
  endfunction: axi_beat_lanes

  `include "axi_agent_cfg.svh"

  `include "axi_txn_request_item.svh"
  `include "axi_read_data_item.svh"

  `include "axi_write_data_item.svh"
  `include "axi_write_response_item.svh"

  `include "axi_response_accept_item.svh"

  `include "axi_status_item.svh"

  `include "axi_mgr_write_request_driver.svh"
  `include "axi_mgr_write_data_driver.svh"
  `include "axi_mgr_write_response_driver.svh"

  `include "axi_mgr_read_request_driver.svh"
  `include "axi_mgr_read_data_driver.svh"

  `include "axi_reset_item.svh"

  // Reset monitor for the shared AXI clock/reset (one instance covers all channels).
  `include "axi_reset_monitor.svh"

  `include "axi_reg_op_item.svh"

  typedef uvm_sequencer#(axi_txn_request_item, axi_status_item)       write_request_sequencer_t;
  `include "axi_mgr_write_data_sequencer.svh"
  typedef axi_mgr_write_data_sequencer                                write_data_sequencer_t;
  typedef uvm_sequencer#(axi_response_accept_item, uvm_sequence_item) write_response_sequencer_t;
  typedef uvm_sequencer#(axi_txn_request_item, axi_status_item)       read_request_sequencer_t;
  typedef uvm_sequencer#(axi_response_accept_item, uvm_sequence_item) read_data_sequencer_t;

  `include "axi_response_router.svh"

  `include "seq_lib/axi_mgr_txn_request_seq.svh"
  `include "seq_lib/axi_mgr_write_data_seq.svh"
  `include "seq_lib/axi_mgr_write_single_data_seq.svh"
  `include "seq_lib/axi_mgr_write_listed_data_seq.svh"
  `include "seq_lib/axi_mgr_write_response_seq.svh"
  `include "seq_lib/axi_mgr_read_data_seq.svh"

  `include "axi_fixed_write_req_item.svh"
  `include "axi_fixed_write_rsp_item.svh"
  `include "seq_lib/axi_mgr_write_fixed_vseq.svh"
  `include "seq_lib/axi_mgr_write_burst_vseq.svh"

  `include "axi_fixed_read_req_item.svh"
  `include "axi_fixed_read_rsp_item.svh"
  `include "seq_lib/axi_mgr_read_fixed_vseq.svh"
  `include "seq_lib/axi_mgr_read_burst_vseq.svh"

  `include "seq_lib/axi_mgr_register_layer_vseq.svh"

  `include "axi_mon_types.svh"
  `include "axi_mon_item.svh"
  `include "axi_mon_write_item.svh"
  `include "axi_mon_read_item.svh"
  `include "axi_monitor.svh"
  `include "axi_reg_adapter.svh"

  `include "axi_agent.svh"
endpackage
