// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Count bus activity for self-test completion checks. tb.sv binds one probe to every axi_if.

interface axi_agent_probe_if
  import axi_widths_pkg::*;
(
  input logic                       clk_i,
  input logic                       rst_ni,

  input logic                       awvalid,
  input logic                       awready,
  input logic [AxiMaxIdWidth-1:0]   awid,
  input logic [AxiMaxAddrWidth-1:0] awaddr,
  input logic [AxiLenWidth-1:0]     awlen,
  input logic [AxiSizeWidth-1:0]    awsize,
  input logic [AxiBurstWidth-1:0]   awburst,
  input logic                       awlock,

  input logic                       wvalid,
  input logic                       wready,
  input logic                       wlast,

  input logic                       bvalid,
  input logic                       bready,
  input logic [AxiMaxIdWidth-1:0]   bid,
  input logic [AxiRespWidth-1:0]    bresp,

  input logic                       arvalid,
  input logic                       arready,
  input logic [AxiMaxIdWidth-1:0]   arid,
  input logic [AxiMaxAddrWidth-1:0] araddr,
  input logic [AxiLenWidth-1:0]     arlen,
  input logic [AxiSizeWidth-1:0]    arsize,
  input logic [AxiBurstWidth-1:0]   arburst,
  input logic                       arlock,

  input logic                       rvalid,
  input logic                       rready,
  input logic [AxiMaxIdWidth-1:0]   rid,
  input logic [AxiRespWidth-1:0]    rresp,
  input logic                       rlast,

  input int unsigned                id_w_width,
  input int unsigned                id_r_width,
  input int unsigned                data_width,
  input bit                         is_lite
);

  typedef bit [AxiMaxIdWidth-1:0] id_t;

  // Per channel: handshakes, VALID waiting, READY before VALID, and consecutive handshakes
  int unsigned m_aw_handshakes, m_w_handshakes, m_b_handshakes, m_ar_handshakes, m_r_handshakes;
  int unsigned m_aw_stalls, m_w_stalls, m_b_stalls, m_ar_stalls, m_r_stalls;
  int unsigned m_aw_ready_first, m_w_ready_first, m_b_ready_first, m_ar_ready_first;
  int unsigned m_r_ready_first;
  int unsigned m_aw_back_to_back, m_w_back_to_back, m_b_back_to_back, m_ar_back_to_back;
  int unsigned m_r_back_to_back;

  // Per channel, in the order AW, W, B, AR, R: the edges in a row at which VALID has waited for
  // READY, and since clear_stall_runs() the longest such run and the shortest before a handshake
  int unsigned m_stall_run[5];
  int unsigned m_max_stall_run[5];
  int unsigned m_min_stall_run[5];

  // AW and AR edges at which VALID waited for READY while an earlier write or read was open
  int unsigned m_aw_stalls_while_open, m_ar_stalls_while_open;

  // AW and AR burst types and shapes. A boundary burst is INCR with its last byte at a 4KB page
  // end.
  int unsigned m_fixed_bursts, m_incr_bursts, m_wrap_bursts;
  int unsigned m_narrow_bursts, m_unaligned_bursts, m_bursts_to_4kb_boundary;
  int unsigned m_exclusive_requests;

  // B responses and R beats with SLVERR, DECERR and EXOKAY
  int unsigned m_slverr_responses, m_decerr_responses, m_exokay_responses;

  // Out-of-order responses across IDs and requests reusing an outstanding ID
  int unsigned m_write_reorders, m_read_reorders;
  int unsigned m_same_id_requests;

  // ID switches before the previous read burst's final beat
  int unsigned m_interleaved_r_beats;

  // Times reset was asserted
  int unsigned m_resets;

  // Since the last reset: AW handshakes, W bursts ended by WLAST (by every W beat in AXI4-Lite),
  // and the W beats of a burst not yet ended
  int unsigned m_aws_since_reset, m_w_bursts_since_reset, m_w_beats_open;

  // Hierarchical name for messages
  string m_path;

  // Clock edges outside reset, latest AW/W/AR handshake edges and first BVALID/RVALID edges for
  // latency measurements
  int unsigned m_edges;
  int unsigned m_aw_hs_edge, m_w_hs_edge, m_ar_hs_edge;
  int unsigned m_b_valid_edge, m_r_valid_edge;

  // Outstanding requests per ID, numbered in acceptance order
  int unsigned m_next_write_seq, m_next_read_seq;
  id_t         m_writes_open[int unsigned];
  id_t         m_reads_open[int unsigned];

  // Previous-edge handshakes, BVALID, RVALID and last R beat
  bit  m_aw_hs_q, m_w_hs_q, m_b_hs_q, m_ar_hs_q, m_r_hs_q;
  bit  m_b_valid_q, m_r_valid_q;
  bit  m_r_last_q;
  id_t m_r_id_q;

  function automatic void count_request(logic [AxiMaxAddrWidth-1:0] addr,
                                        logic [AxiLenWidth-1:0]     len,
                                        logic [AxiSizeWidth-1:0]    size,
                                        logic [AxiBurstWidth-1:0]   burst,
                                        logic                       lock);
    int unsigned nbytes = 1 << size;

    m_fixed_bursts       += (burst == 2'b00);
    m_incr_bursts        += (burst == 2'b01);
    m_wrap_bursts        += (burst == 2'b10);
    m_narrow_bursts      += (nbytes < data_width / 8);
    m_unaligned_bursts   += (addr % nbytes != 0);
    m_exclusive_requests += lock;
    if (burst == 2'b01 && ((((addr >> size) + len + 1) << size) % 4096) == 0) begin
      m_bursts_to_4kb_boundary++;
    end
  endfunction : count_request

  function automatic void count_response(logic [AxiRespWidth-1:0] resp);
    m_slverr_responses += (resp[1:0] == 2'b10);
    m_decerr_responses += (resp[1:0] == 2'b11);
    m_exokay_responses += (resp[1:0] == 2'b01);
  endfunction : count_response

  // Close this ID's oldest request and return 1 if an older request with another ID remains
  function automatic bit close_request(ref id_t open[int unsigned], input id_t id);
    int unsigned seq;
    bit          found = 1'b0;
    bit          overtook = 1'b0;

    foreach (open[s]) begin
      if (open[s] == id) begin
        seq   = s;
        found = 1'b1;
        break;
      end
    end
    if (!found) begin
      return 1'b0;
    end
    foreach (open[s]) begin
      if (s < seq && open[s] != id) begin
        overtook = 1'b1;
        break;
      end
    end
    open.delete(seq);
    return overtook;
  endfunction : close_request

  function automatic bit id_is_open(ref id_t open[int unsigned], input id_t id);
    foreach (open[s]) begin
      if (open[s] == id) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction : id_is_open

  function automatic void clear_stall_runs();
    foreach (m_max_stall_run[c]) begin
      m_max_stall_run[c] = 0;
      m_min_stall_run[c] = '1;
    end
  endfunction : clear_stall_runs

  initial begin
    m_path = $sformatf("%m");
    clear_stall_runs();
  end

  always @(negedge rst_ni) begin
    m_resets++;
    m_aws_since_reset      = 0;
    m_w_bursts_since_reset = 0;
    m_w_beats_open         = 0;
    m_writes_open.delete();
    m_reads_open.delete();
    foreach (m_stall_run[c]) begin
      m_stall_run[c] = 0;
    end
    m_aw_hs_q   = 1'b0;
    m_w_hs_q    = 1'b0;
    m_b_hs_q    = 1'b0;
    m_ar_hs_q   = 1'b0;
    m_r_hs_q    = 1'b0;
    m_r_last_q  = 1'b1;
    m_b_valid_q = 1'b0;
    m_r_valid_q = 1'b0;
  end

  always @(posedge clk_i) begin
    if (rst_ni === 1'b1) begin
      bit  aw_hs, w_hs, b_hs, ar_hs, r_hs;
      bit  stalled[5], handshake[5];
      id_t aw_id, b_id, ar_id, r_id;

      aw_hs = (awvalid === 1'b1 && awready === 1'b1);
      w_hs  = (wvalid === 1'b1 && wready === 1'b1);
      b_hs  = (bvalid === 1'b1 && bready === 1'b1);
      ar_hs = (arvalid === 1'b1 && arready === 1'b1);
      r_hs  = (rvalid === 1'b1 && rready === 1'b1);
      aw_id = awid & ((AxiMaxIdWidth'(1) << id_w_width) - 1);
      b_id  = bid & ((AxiMaxIdWidth'(1) << id_w_width) - 1);
      ar_id = arid & ((AxiMaxIdWidth'(1) << id_r_width) - 1);
      r_id  = rid & ((AxiMaxIdWidth'(1) << id_r_width) - 1);

      m_aw_handshakes   += aw_hs;
      m_w_handshakes    += w_hs;
      m_b_handshakes    += b_hs;
      m_ar_handshakes   += ar_hs;
      m_r_handshakes    += r_hs;
      m_aw_stalls       += (awvalid === 1'b1 && awready !== 1'b1);
      m_w_stalls        += (wvalid === 1'b1 && wready !== 1'b1);
      m_b_stalls        += (bvalid === 1'b1 && bready !== 1'b1);
      m_ar_stalls       += (arvalid === 1'b1 && arready !== 1'b1);
      m_r_stalls        += (rvalid === 1'b1 && rready !== 1'b1);
      m_aw_ready_first  += (awready === 1'b1 && awvalid !== 1'b1);
      m_w_ready_first   += (wready === 1'b1 && wvalid !== 1'b1);
      m_b_ready_first   += (bready === 1'b1 && bvalid !== 1'b1);
      m_ar_ready_first  += (arready === 1'b1 && arvalid !== 1'b1);
      m_r_ready_first   += (rready === 1'b1 && rvalid !== 1'b1);
      m_aw_back_to_back += (aw_hs && m_aw_hs_q);
      m_w_back_to_back  += (w_hs && m_w_hs_q);
      m_b_back_to_back  += (b_hs && m_b_hs_q);
      m_ar_back_to_back += (ar_hs && m_ar_hs_q);
      m_r_back_to_back  += (r_hs && m_r_hs_q);
      m_aw_stalls_while_open += (awvalid === 1'b1 && awready !== 1'b1 && m_writes_open.size() > 0);
      m_ar_stalls_while_open += (arvalid === 1'b1 && arready !== 1'b1 && m_reads_open.size() > 0);

      stalled   = '{awvalid === 1'b1 && awready !== 1'b1, wvalid === 1'b1 && wready !== 1'b1,
                    bvalid === 1'b1 && bready !== 1'b1, arvalid === 1'b1 && arready !== 1'b1,
                    rvalid === 1'b1 && rready !== 1'b1};
      handshake = '{aw_hs, w_hs, b_hs, ar_hs, r_hs};
      foreach (stalled[c]) begin
        if (handshake[c] && m_stall_run[c] < m_min_stall_run[c]) begin
          m_min_stall_run[c] = m_stall_run[c];
        end
        m_stall_run[c] = stalled[c] ? m_stall_run[c] + 1 : 0;
        if (m_stall_run[c] > m_max_stall_run[c]) begin
          m_max_stall_run[c] = m_stall_run[c];
        end
      end

      m_edges++;
      if (aw_hs) begin
        m_aw_hs_edge = m_edges;
      end
      if (w_hs) begin
        m_w_hs_edge = m_edges;
      end
      if (ar_hs) begin
        m_ar_hs_edge = m_edges;
      end

      // A new response follows low VALID or a handshake at the previous edge
      if (bvalid === 1'b1 && (!m_b_valid_q || m_b_hs_q)) begin
        m_b_valid_edge = m_edges;
      end
      if (rvalid === 1'b1 && (!m_r_valid_q || m_r_hs_q)) begin
        m_r_valid_edge = m_edges;
      end
      m_b_valid_q = (bvalid === 1'b1);
      m_r_valid_q = (rvalid === 1'b1);

      if (b_hs) begin
        count_response(bresp);
        m_write_reorders += close_request(m_writes_open, b_id);
      end
      if (r_hs) begin
        count_response(rresp);
        if (m_r_hs_q && !m_r_last_q && r_id != m_r_id_q) begin
          m_interleaved_r_beats++;
        end
        if (rlast === 1'b1) begin
          m_read_reorders += close_request(m_reads_open, r_id);
        end
        m_r_last_q = (rlast === 1'b1);
        m_r_id_q   = r_id;
      end
      if (aw_hs) begin
        count_request(awaddr, awlen, awsize, awburst, awlock);
        m_same_id_requests += id_is_open(m_writes_open, aw_id);
        m_writes_open[m_next_write_seq++] = aw_id;
      end
      if (ar_hs) begin
        count_request(araddr, arlen, arsize, arburst, arlock);
        m_same_id_requests += id_is_open(m_reads_open, ar_id);
        m_reads_open[m_next_read_seq++] = ar_id;
      end
      m_aws_since_reset += aw_hs;
      if (w_hs) begin
        if (is_lite || wlast === 1'b1) begin
          m_w_bursts_since_reset++;
          m_w_beats_open = 0;
        end else begin
          m_w_beats_open++;
        end
      end

      m_aw_hs_q = aw_hs;
      m_w_hs_q  = w_hs;
      m_b_hs_q  = b_hs;
      m_ar_hs_q = ar_hs;
      m_r_hs_q  = r_hs;
    end
  end

endinterface : axi_agent_probe_if
