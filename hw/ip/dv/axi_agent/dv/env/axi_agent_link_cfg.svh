// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Link endpoints, routing and scoreboard expectations (see tb.sv)

class axi_agent_link_cfg extends uvm_object;
  `uvm_object_utils(axi_agent_link_cfg)

  // How a transaction gets from a manager end to a subordinate end
  typedef enum {
    // Both ends watch one bus
    LinkSameBus,
    // axi_to_axi_lite turns each beat into an AXI4-Lite transfer
    LinkLiteBridge,
    // axi_xbar routes by address and widens the ID with the index of the manager port
    LinkXbar
  } link_kind_e;

  // An error response that a subordinate which is not the agent gives to the bytes lo to hi
  typedef struct {
    bit [AxiMaxAddrWidth-1:0] lo;
    bit [AxiMaxAddrWidth-1:0] hi;
    axi_resp_e                resp;
  } err_range_t;

  // The bytes lo to hi that the crossbar routes to subordinate end sub
  typedef struct {
    bit [AxiMaxAddrWidth-1:0] lo;
    bit [AxiMaxAddrWidth-1:0] hi;
    int unsigned              sub;
  } route_t;

  // Link name used for interfaces in tb.sv
  string m_name = "agent";

  link_kind_e m_kind = LinkSameBus;

  // The number of manager and subordinate ends
  int unsigned m_num_mgrs = 1;
  int unsigned m_num_subs = 1;

  // Active agent endpoints (agents at pulp_axi endpoints monitor passively)
  bit m_mgr_is_agent = 1'b1;
  bit m_sub_is_agent = 1'b1;

  // The address window that the link's traffic uses
  bit [AxiMaxAddrWidth-1:0] m_addr_lo = AxiWinBase;
  bit [AxiMaxAddrWidth-1:0] m_addr_hi = AxiWinBase + AxiWinBytes - 1;

  // Crossbar address map, where unmapped addresses get DECERR (AMBA AXI H.c A3.4.5)
  route_t m_routes[$];

  // Whether the far end takes WRAP bursts, and FIXED bursts that start unaligned
  bit m_allows_wrap            = 1'b1;
  bit m_allows_unaligned_fixed = 1'b1;

  // Predict read data only when reads cannot overlap writes to the same bytes. Self-test sequences
  // enforce this, and pulp_axi manager tests enable prediction after writes finish. The scoreboard
  // takes the value it has when the subordinate end sees each read request.
  bit m_predict_reads = 1'b1;

  // Predict response codes (disabled for randomly chosen errors)
  bit m_predict_responses = 1'b1;

  // Allow external subordinates to update memory on write errors, which AMBA AXI H.c leaves
  // unspecified
  bit m_error_writes_may_update = 1'b0;

  // Serialize manager writes through B before sending the next AW
  bit m_serial_writes = 1'b0;

  // Allow DECERR behind the bridge. axi_to_axi_lite answers SLVERR to a multi-beat burst whose
  // first error is DECERR.
  bit m_bridge_decerr = 1'b0;

  // Address-based errors from external subordinates, where writes count only strobed bytes
  err_range_t m_model_err_ranges[$];

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  // Configure the named link. +axi_link_allows_wrap, +axi_link_allows_unaligned_fixed,
  // +axi_link_serial_writes and +axi_link_bridge_decerr override settings that avoid known pulp_axi
  // defects for reproducer tests.
  extern function void configure(string name);

  // Return the subordinate end that the crossbar routes addr to, or -1 for none
  extern function int route(bit [AxiMaxAddrWidth-1:0] addr);
endclass : axi_agent_link_cfg


function axi_agent_link_cfg::new(string name = "");
  super.new(name);
endfunction : new

function void axi_agent_link_cfg::configure(string name);
  err_range_t range;
  route_t     rt;

  m_name = name;
  case (name)
    "agent": begin
    end
    "pulp_mgr": begin
      // A pulp_axi manager may read bytes that a write in flight is changing
      m_mgr_is_agent  = 1'b0;
      m_predict_reads = 1'b0;
    end
    "pulp_lite_mgr": begin
      m_mgr_is_agent = 1'b0;
    end
    "sim_mem": begin
      // axi_sim_mem writes even on errors and extends later unaligned FIXED beats beyond their
      // container
      m_sub_is_agent            = 1'b0;
      m_error_writes_may_update = 1'b1;
      m_allows_unaligned_fixed  = 1'b0;
      m_addr_hi                 = AxiWinBase + SimMemWinBytes - 1;
      range.lo   = SimMemSlverrPage;
      range.hi   = SimMemSlverrPage + 4095;
      range.resp = RespSlverr;
      m_model_err_ranges.push_back(range);
      range.lo   = SimMemDecerrPage;
      range.hi   = SimMemDecerrPage + 4095;
      range.resp = RespDecerr;
      m_model_err_ranges.push_back(range);
    end
    "rand_slave": begin
      // axi_rand_slave does not support WRAP in MAPPED mode and misaddresses later writes while an
      // earlier B is pending, so serialize writes
      m_sub_is_agent  = 1'b0;
      m_allows_wrap   = 1'b0;
      m_serial_writes = 1'b1;
    end
    "lite_regs": begin
      m_sub_is_agent = 1'b0;
      m_addr_lo      = LiteRegsBase;
      m_addr_hi      = LiteRegsBase + LiteRegsBytes - 1;
    end
    "lite_rand_slave": begin
      // axi_lite_rand_slave has no memory and answers with random data and responses
      m_sub_is_agent      = 1'b0;
      m_predict_reads     = 1'b0;
      m_predict_responses = 1'b0;
    end
    "lite_bridge": begin
      // axi_to_axi_lite splits a WRAP burst as if it were FIXED
      m_kind        = LinkLiteBridge;
      m_allows_wrap = 1'b0;
    end
    "lite_to_axi": begin
      m_mgr_is_agent = 1'b0;
    end
    "xbar": begin
      // Match tb.sv: two managers, three subordinates, top 4KB unmapped
      m_kind     = LinkXbar;
      m_num_mgrs = XbarNumMgrs;
      m_num_subs = XbarNumSubs;
      for (int unsigned s = 0; s < XbarNumSubs; s++) begin
        rt.lo  = AxiWinBase + s * XbarSubBytes;
        rt.hi  = rt.lo + XbarSubBytes - 1;
        rt.sub = s;
        m_routes.push_back(rt);
      end
    end
    default: begin
      `uvm_fatal(get_name(), $sformatf("There is no link called %0s in tb.sv.", name))
    end
  endcase

  void'($value$plusargs("axi_link_allows_wrap=%0b", m_allows_wrap));
  void'($value$plusargs("axi_link_allows_unaligned_fixed=%0b", m_allows_unaligned_fixed));
  void'($value$plusargs("axi_link_serial_writes=%0b", m_serial_writes));
  void'($value$plusargs("axi_link_bridge_decerr=%0b", m_bridge_decerr));
endfunction : configure

function int axi_agent_link_cfg::route(bit [AxiMaxAddrWidth-1:0] addr);
  if (m_kind != LinkXbar) begin
    return 0;
  end
  foreach (m_routes[i]) begin
    if (addr >= m_routes[i].lo && addr <= m_routes[i].hi) begin
      return m_routes[i].sub;
    end
  end
  return -1;
endfunction : route
