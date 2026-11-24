// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Configuration for an AXI subordinate agent

class axi_sub_agent_cfg extends uvm_object;
  `uvm_object_utils(axi_sub_agent_cfg)

  // Backing memory, created by the agent if null
  axi_mem_model_t m_mem;

  // Read value for an address that is absent from m_mem
  bit [7:0] m_default_byte = 8'h0;

  // Minimum cycles before BVALID or first RVALID once answerable, when no sequence policy is
  // available
  int unsigned m_default_latency = 0;

  // Address error injection, disabled by default: match (addr & ~m_err_addr_mask) == (m_err_addr &
  // ~m_err_addr_mask). Mask 0 selects one byte and 'hfff selects a 4KB region. Return m_err_resp on
  // each matching read beat or on B for a write touching any matching byte.
  bit        m_err_addr_valid = 1'b0;
  bit [63:0] m_err_addr       = '0;
  bit [63:0] m_err_addr_mask  = '0;
  axi_resp_e m_err_resp       = RespSlverr;

  // Zero inactive read lanes when set. Otherwise, return memory bytes from the same bus word. AXI
  // leaves these lanes unspecified (AMBA AXI H.c A3.4.4).
  bit m_zero_inactive_lanes = 1'b1;

  // How the subordinate drives AWREADY, WREADY and ARREADY (see axi_sub_ready_cfg)
  axi_sub_ready_cfg m_aw_ready;
  axi_sub_ready_cfg m_w_ready;
  axi_sub_ready_cfg m_ar_ready;

  // Outstanding write and read limits (zero means unlimited). Hold AWREADY or ARREADY low at the
  // limit, while a waiting request's READY delay still counts from VALID. Count a transaction until
  // the edge after its B or last R handshake.
  int unsigned m_max_outstanding_writes = 0;
  int unsigned m_max_outstanding_reads  = 0;

  // Maximum idle cycles between read beats
  int unsigned m_max_read_beat_gap = 0;

  // Allow responses out of order across IDs when set. Otherwise, follow acceptance order. Same-ID
  // responses always remain ordered (H.c A5.1).
  bit m_out_of_order = 1'b0;

  // Allow read beats to interleave across IDs (H.c E1.12), which requires m_out_of_order
  bit m_read_interleave = 1'b0;

  // Enable exclusive accesses with a monitor per ID (H.c A7.2). Exclusive reads get EXOKAY.
  // Matching writes get EXOKAY and update memory if no intervening write touched their bytes.
  // Failed exclusive writes get OKAY without changing memory. When disabled, ignore AxLOCK: return
  // OKAY and carry out writes.
  bit m_exclusive_support = 1'b0;

  // What an AXI4-Lite subordinate does with WSTRB (H.c B1.1.3)
  axi_lite_strb_policy_e m_lite_strb_policy = AxiLiteStrbUse;

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  // Return whether this byte hits the error region
  extern function bit addr_is_error(bit [63:0] addr);

  // Report incompatible settings or bus properties with uvm_error
  extern function void check_settings(bit is_lite, int unsigned data_width);
endclass : axi_sub_agent_cfg


function axi_sub_agent_cfg::new(string name = "");
  super.new(name);
  m_aw_ready = axi_sub_ready_cfg::type_id::create("m_aw_ready");
  m_w_ready  = axi_sub_ready_cfg::type_id::create("m_w_ready");
  m_ar_ready = axi_sub_ready_cfg::type_id::create("m_ar_ready");
endfunction : new

function bit axi_sub_agent_cfg::addr_is_error(bit [63:0] addr);
  if (!m_err_addr_valid) begin
    return 1'b0;
  end
  return ((addr & ~m_err_addr_mask) == (m_err_addr & ~m_err_addr_mask));
endfunction : addr_is_error

function void axi_sub_agent_cfg::check_settings(bit is_lite, int unsigned data_width);
  if (m_err_addr_valid && !(m_err_resp inside {RespSlverr, RespDecerr})) begin
    `uvm_error(get_name(), $sformatf("m_err_resp must be SLVERR or DECERR, not %0s.",
                                     m_err_resp.name()))
  end
  if (m_read_interleave && !m_out_of_order) begin
    `uvm_error(get_name(), "m_read_interleave needs m_out_of_order.")
  end
  if (is_lite) begin
    // AXI4-Lite has no IDs or exclusive accesses. Responses stay ordered and read beats cannot
    // interleave (H.c B1.1, B1.1.4).
    if (m_out_of_order || m_read_interleave) begin
      `uvm_error(get_name(), "An AXI4-Lite subordinate cannot answer out of order or interleave.")
    end
    if (m_exclusive_support) begin
      `uvm_error(get_name(), "An AXI4-Lite subordinate cannot support exclusive accesses.")
    end
    if (!(data_width inside {32, 64})) begin
      `uvm_error(get_name(), $sformatf("AXI4-Lite needs a 32 or 64 bit data bus, not %0d bits.",
                                       data_width))
    end
  end
endfunction : check_settings
