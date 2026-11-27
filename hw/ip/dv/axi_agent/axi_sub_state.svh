// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Shared memory and outstanding transactions for the five subordinate drivers. AW, W and AR add
// work, while B and R select responses in protocol order and remove completed work. Every driver
// flushes state on reset, preventing pre-reset responses.

class axi_sub_state extends uvm_object;
  `uvm_object_utils(axi_sub_state)

  // W beats may arrive before AW (AMBA AXI H.c A3.3.1)
  typedef struct {
    logic [AxiMaxDataWidth-1:0]     data;
    logic [AxiMaxStrbWidth-1:0]     strb;
    logic [AxiMaxDataUserWidth-1:0] user;
  } w_beat_t;

  // Configuration, set with set_cfg()
  local axi_sub_agent_cfg m_cfg;

  // AXI4-Lite mode and data width in bytes, set with set_bus()
  local bit          m_is_lite;
  local int unsigned m_bus_bytes;

  // Writes waiting for W data, in AW order. Each W beat belongs to the oldest (H.c A5.2.2).
  local axi_sub_txn m_wait_w_q[$];
  local w_beat_t    m_early_w_q[$];

  // Writes with complete data awaiting or holding B, in AW order
  local axi_sub_txn m_b_q[$];

  // Reads awaiting their final R handshake, in AR order
  local axi_sub_txn m_r_q[$];

  // The number of writes and reads accepted since the last reset
  local int unsigned m_num_writes;
  local int unsigned m_num_reads;

  // Exclusive monitor per ID: last exclusive read, valid until a write touches its bytes (H.c
  // A7.2.3)
  local axi_sub_txn m_excl_reads[int unsigned];

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  // Configure before the channel drivers run
  extern function void set_cfg(axi_sub_agent_cfg cfg);
  extern function void set_bus(bit is_lite, int unsigned bus_bytes);

  // Discard outstanding transactions on reset
  extern function void flush();

  // Return whether the subordinate can accept another write or read request
  extern function bit can_accept_write();
  extern function bit can_accept_read();

  // Record accepted AW values or a W beat and return the transaction
  extern function axi_sub_txn add_write_request(axi_txn_request_item req, axi_sub_rsp_item policy);
  extern function void add_write_beat(logic [AxiMaxDataWidth-1:0]     data,
                                      logic [AxiMaxStrbWidth-1:0]     strb,
                                      logic [AxiMaxDataUserWidth-1:0] user);

  // Record accepted AR, compute read data and responses, and return the transaction
  extern function axi_sub_txn add_read_request(axi_txn_request_item req, axi_sub_rsp_item policy);

  // B and R decrement latency after selecting each edge's response. A transaction answerable at an
  // edge with latency L first asserts VALID at least L + 1 edges later. Channel activity and
  // response selection may delay it further.
  extern function void tick_writes();
  extern function void tick_reads();

  // Return the write to answer next on B, or null if none can be answered yet
  extern function axi_sub_txn pick_write_response();

  // Return the next read to send, or null if none is ready. current is the burst in progress, or
  // null.
  extern function axi_sub_txn pick_read_beat(axi_sub_txn current);

  // Remove a write after its B handshake, or a read after its last R handshake
  extern function void write_done(axi_sub_txn txn);
  extern function void read_done(axi_sub_txn txn);

  // Build the subordinate's view of a request: the burst it carries out
  extern local function axi_sub_txn new_txn(bit                  is_write,
                                            axi_txn_request_item req,
                                            axi_sub_rsp_item     policy);

  // Attach a W beat to the oldest write waiting for data, completing it if it was the last beat
  extern local function void attach_beat(w_beat_t beat);

  // Decide the response to a write with all its data, update memory and queue it for B
  extern local function void complete_write(axi_sub_txn txn);

  // Return whether beat n of txn touches a byte in the configured error region
  extern local function bit beat_hits_error(axi_sub_txn txn, int unsigned n);

  // Return the memory byte at addr, or the default byte if the memory does not map it
  extern local function bit [7:0] read_mem_byte(bit [AxiMaxAddrWidth-1:0] addr);

  // Clear every exclusive access monitor that covers the byte at addr
  extern local function void clear_excl_monitors(bit [AxiMaxAddrWidth-1:0] addr);

  // Return whether the request is an exclusive access that the subordinate treats as one
  extern local function bit is_exclusive(axi_sub_txn txn);

  // Check that an exclusive write matches its ID's monitored read on all AXI4 attributes in H.c
  // A7.2.4
  extern local function bit excl_write_matches(axi_sub_txn txn);
endclass : axi_sub_state


function axi_sub_state::new(string name = "");
  super.new(name);
endfunction : new

function void axi_sub_state::set_cfg(axi_sub_agent_cfg cfg);
  m_cfg = cfg;
endfunction : set_cfg

function void axi_sub_state::set_bus(bit is_lite, int unsigned bus_bytes);
  m_is_lite   = is_lite;
  m_bus_bytes = bus_bytes;
endfunction : set_bus

function void axi_sub_state::flush();
  m_wait_w_q.delete();
  m_early_w_q.delete();
  m_b_q.delete();
  m_r_q.delete();
  m_num_writes = 0;
  m_num_reads = 0;
  m_excl_reads.delete();
endfunction : flush

function bit axi_sub_state::can_accept_write();
  return (m_cfg.m_max_outstanding_writes == 0 ||
          m_wait_w_q.size() + m_b_q.size() < m_cfg.m_max_outstanding_writes);
endfunction : can_accept_write

function bit axi_sub_state::can_accept_read();
  return (m_cfg.m_max_outstanding_reads == 0 || m_r_q.size() < m_cfg.m_max_outstanding_reads);
endfunction : can_accept_read

function axi_sub_txn axi_sub_state::new_txn(bit                  is_write,
                                            axi_txn_request_item req,
                                            axi_sub_rsp_item     policy);
  axi_sub_txn txn = axi_sub_txn::type_id::create(is_write ? "write_txn" : "read_txn");

  txn.m_is_write = is_write;
  txn.m_req      = req;
  txn.m_policy   = policy;
  if (m_is_lite) begin
    // AXI4-Lite omits AxLEN, AxSIZE and AxBURST: use one full-width transfer (H.c B1.1.1)
    txn.m_len   = 0;
    txn.m_size  = $clog2(m_bus_bytes);
    txn.m_burst = BurstIncr;
  end else begin
    txn.m_len   = req.m_len;
    txn.m_size  = req.m_size;
    txn.m_burst = req.m_burst;
  end
  return txn;
endfunction : new_txn

function axi_sub_txn axi_sub_state::add_write_request(axi_txn_request_item req,
                                                      axi_sub_rsp_item     policy);
  axi_sub_txn txn = new_txn(1'b1, req, policy);

  txn.m_accept_idx = m_num_writes++;
  m_wait_w_q.push_back(txn);
  while (m_wait_w_q.size() > 0 && m_early_w_q.size() > 0) begin
    attach_beat(m_early_w_q.pop_front());
  end
  return txn;
endfunction : add_write_request

function void axi_sub_state::add_write_beat(logic [AxiMaxDataWidth-1:0]     data,
                                            logic [AxiMaxStrbWidth-1:0]     strb,
                                            logic [AxiMaxDataUserWidth-1:0] user);
  w_beat_t beat;

  beat.data = data;
  beat.strb = strb;
  beat.user = user;
  if (m_wait_w_q.size() > 0) begin
    attach_beat(beat);
  end else begin
    m_early_w_q.push_back(beat);
  end
endfunction : add_write_beat

function void axi_sub_state::attach_beat(w_beat_t beat);
  axi_sub_txn txn = m_wait_w_q[0];

  // AWLEN determines burst length, and protocol assertions check WLAST
  txn.m_wdata.push_back(beat.data);
  txn.m_wstrb.push_back(beat.strb);
  txn.m_wuser.push_back(beat.user);
  if (txn.m_wdata.size() == txn.num_beats()) begin
    void'(m_wait_w_q.pop_front());
    complete_write(txn);
  end
endfunction : attach_beat

function bit axi_sub_state::beat_hits_error(axi_sub_txn txn, int unsigned n);
  bit [AxiMaxAddrWidth-1:0] addr;
  int unsigned              lower, upper;

  txn.get_beat(n, m_bus_bytes, addr, lower, upper);
  for (int unsigned lane = lower; lane <= upper; lane++) begin
    if (m_cfg.addr_is_error(addr - (addr % m_bus_bytes) + lane)) begin
      return 1'b1;
    end
  end
  return 1'b0;
endfunction : beat_hits_error

function bit [7:0] axi_sub_state::read_mem_byte(bit [AxiMaxAddrWidth-1:0] addr);
  if (m_cfg.m_mem.addr_is_mapped(addr)) begin
    return m_cfg.m_mem.read_byte(addr);
  end
  return m_cfg.m_default_byte;
endfunction : read_mem_byte

function bit axi_sub_state::is_exclusive(axi_sub_txn txn);
  // AXI4-Lite omits AxLOCK, so all accesses are normal (H.c B1.1.1)
  return m_cfg.m_exclusive_support && !m_is_lite && txn.m_req.m_lock;
endfunction : is_exclusive

function bit axi_sub_state::excl_write_matches(axi_sub_txn txn);
  axi_txn_request_item rd;
  axi_txn_request_item wr = txn.m_req;

  if (!m_excl_reads.exists(wr.m_id)) begin
    return 1'b0;
  end
  rd = m_excl_reads[wr.m_id].m_req;
  return (rd.m_addr == wr.m_addr && rd.m_region == wr.m_region && rd.m_len == wr.m_len &&
          rd.m_size == wr.m_size && rd.m_burst == wr.m_burst && rd.m_lock == wr.m_lock &&
          rd.m_cache == wr.m_cache && rd.m_prot == wr.m_prot);
endfunction : excl_write_matches

function void axi_sub_state::complete_write(axi_sub_txn txn);
  bit        error  = 1'b0;
  axi_resp_e resp   = RespOkay;
  bit        update = 1'b1;
  bit        exokay = 1'b0;

  // An error-region hit, policy error or rejected AXI4-Lite strobe pattern
  // (AxiLiteStrbErrorPartial) fails the write. Errors leave memory unchanged.
  for (int unsigned n = 0; n < txn.num_beats() && !error; n++) begin
    if (beat_hits_error(txn, n)) begin
      error = 1'b1;
      resp  = m_cfg.m_err_resp;
    end
  end
  if (!error && txn.m_policy.m_force_error) begin
    error = 1'b1;
    resp  = txn.m_policy.m_error_resp;
  end
  if (!error && m_is_lite && m_cfg.m_lite_strb_policy == AxiLiteStrbErrorPartial &&
      txn.m_wstrb[0] !== ((AxiMaxStrbWidth'(1) << m_bus_bytes) - 1)) begin
    error = 1'b1;
    resp  = RespSlverr;
  end
  if (error) begin
    update = 1'b0;
  end

  // Update memory only if the exclusive write matches its ID's valid monitored read (H.c A7.2.3)
  if (!error && is_exclusive(txn)) begin
    exokay = excl_write_matches(txn);
    update = exokay;
  end

  for (int unsigned n = 0; n < txn.num_beats() && update; n++) begin
    bit [AxiMaxAddrWidth-1:0] addr;
    int unsigned              lower, upper;

    txn.get_beat(n, m_bus_bytes, addr, lower, upper);
    for (int unsigned lane = lower; lane <= upper; lane++) begin
      bit [AxiMaxAddrWidth-1:0] byte_addr = addr - (addr % m_bus_bytes) + lane;
      logic [7:0]               wbyte = txn.m_wdata[n][8 * lane +: 8];

      if (txn.m_wstrb[n][lane] !== 1'b1 &&
          !(m_is_lite && m_cfg.m_lite_strb_policy == AxiLiteStrbIgnore)) begin
        continue;
      end
      // A manager may drive any value on a lane that it does not strobe (H.c A3.4.4)
      if (txn.m_wstrb[n][lane] === 1'b1 && $isunknown(wbyte)) begin
        `uvm_error(get_name(), $sformatf("Write %0s beat %0d: byte 0x%0h at lane %0d is 0x%0h.",
                                         txn.convert2string(), n, byte_addr, lane, wbyte))
      end
      m_cfg.m_mem.write_byte(byte_addr, wbyte);
      clear_excl_monitors(byte_addr);
    end
  end

  if (error) begin
    txn.m_bresp = resp;
  end else begin
    txn.m_bresp = exokay ? RespExOkay : RespOkay;
  end

  txn.m_cycles_to_ready = txn.m_policy.m_latency;
  m_b_q.push_back(txn);
endfunction : complete_write

function axi_sub_txn axi_sub_state::add_read_request(axi_txn_request_item req,
                                                     axi_sub_rsp_item     policy);
  axi_sub_txn txn = new_txn(1'b0, req, policy);
  bit         any_error = 1'b0;

  txn.m_accept_idx = m_num_reads++;

  // Snapshot read data at acceptance, including writes answered before that point
  for (int unsigned n = 0; n < txn.num_beats(); n++) begin
    bit [AxiMaxAddrWidth-1:0] addr;
    int unsigned              lower, upper;
    bit [AxiMaxDataWidth-1:0] data = '0;
    bit [AxiMaxAddrWidth-1:0] word = '0;
    axi_resp_e                resp = RespOkay;

    if (beat_hits_error(txn, n)) begin
      resp = m_cfg.m_err_resp;
    end else if (policy.m_force_error) begin
      resp = policy.m_error_resp;
    end
    any_error |= (resp != RespOkay);

    txn.get_beat(n, m_bus_bytes, addr, lower, upper);
    word = addr - (addr % m_bus_bytes);
    for (int unsigned lane = 0; lane < m_bus_bytes; lane++) begin
      if (lane >= lower && lane <= upper) begin
        data[8 * lane +: 8] = read_mem_byte(word + lane);
      end else if (!m_cfg.m_zero_inactive_lanes) begin
        data[8 * lane +: 8] = read_mem_byte(word + lane);
      end
    end

    txn.m_rdata.push_back(data);
    txn.m_rresp.push_back(resp);
  end

  // An exclusive read sets its ID's monitor and gets EXOKAY on every beat (H.c A7.2.3, A7.2.5). An
  // error on any beat records no address but still clears the previous exclusive read for that ID
  // (A7.2.1).
  if (is_exclusive(txn)) begin
    if (any_error) begin
      m_excl_reads.delete(req.m_id);
    end else begin
      m_excl_reads[req.m_id] = txn;
      foreach (txn.m_rresp[n]) begin
        txn.m_rresp[n] = RespExOkay;
      end
    end
  end

  txn.m_cycles_to_ready = policy.m_latency;
  m_r_q.push_back(txn);
  return txn;
endfunction : add_read_request

function void axi_sub_state::clear_excl_monitors(bit [AxiMaxAddrWidth-1:0] addr);
  int unsigned ids[$];

  // Exclusive reads are size-aligned (H.c A7.2.4). Compare offsets from the read address to avoid
  // wrapping at the top of the address space.
  foreach (m_excl_reads[id]) begin
    bit [AxiMaxAddrWidth-1:0] base  = m_excl_reads[id].m_req.m_addr;
    int unsigned              bytes = m_excl_reads[id].num_beats() << m_excl_reads[id].m_size;

    if (addr >= base && addr - base < bytes) begin
      ids.push_back(id);
    end
  end
  foreach (ids[i]) begin
    m_excl_reads.delete(ids[i]);
  end
endfunction : clear_excl_monitors

function void axi_sub_state::tick_writes();
  foreach (m_b_q[i]) begin
    if (m_b_q[i].m_cycles_to_ready > 0) begin
      m_b_q[i].m_cycles_to_ready--;
    end
  end
endfunction : tick_writes

function void axi_sub_state::tick_reads();
  foreach (m_r_q[i]) begin
    if (m_r_q[i].m_cycles_to_ready > 0) begin
      m_r_q[i].m_cycles_to_ready--;
    end
  end
endfunction : tick_reads

function axi_sub_txn axi_sub_state::pick_write_response();
  axi_sub_txn ready[$];
  bit         id_seen[int unsigned];

  // Without m_out_of_order, only the oldest write can respond
  if (!m_cfg.m_out_of_order) begin
    if (m_b_q.size() > 0 && m_b_q[0].m_cycles_to_ready == 0) begin
      return m_b_q[0];
    end
    return null;
  end

  // Choose any ID's oldest write (H.c A5.1). Writes still waiting for data are newer.
  foreach (m_b_q[i]) begin
    int unsigned id = m_b_q[i].m_req.m_id;
    if (id_seen.exists(id)) begin
      continue;
    end
    id_seen[id] = 1'b1;
    if (m_b_q[i].m_cycles_to_ready == 0) begin
      ready.push_back(m_b_q[i]);
    end
  end
  if (ready.size() == 0) begin
    return null;
  end
  return ready[$urandom_range(0, ready.size() - 1)];
endfunction : pick_write_response

function axi_sub_txn axi_sub_state::pick_read_beat(axi_sub_txn current);
  axi_sub_txn ready[$];
  bit         id_seen[int unsigned];

  // Finish the current burst unless interleaving is enabled
  if (current != null && !m_cfg.m_read_interleave) begin
    return current;
  end

  if (!m_cfg.m_out_of_order) begin
    if (m_r_q.size() > 0 && m_r_q[0].m_cycles_to_ready == 0) begin
      return m_r_q[0];
    end
    return null;
  end

  // Choose any ID's oldest read, including interrupted bursts when m_read_interleave is set
  foreach (m_r_q[i]) begin
    int unsigned id = m_r_q[i].m_req.m_id;
    if (id_seen.exists(id)) begin
      continue;
    end
    id_seen[id] = 1'b1;
    if (m_r_q[i].m_cycles_to_ready == 0) begin
      ready.push_back(m_r_q[i]);
    end
  end
  if (ready.size() == 0) begin
    return null;
  end
  return ready[$urandom_range(0, ready.size() - 1)];
endfunction : pick_read_beat

function void axi_sub_state::write_done(axi_sub_txn txn);
  foreach (m_b_q[i]) begin
    if (m_b_q[i] == txn) begin
      m_b_q.delete(i);
      return;
    end
  end
  `uvm_fatal(get_name(), $sformatf("Write %0s is not waiting for B.", txn.convert2string()))
endfunction : write_done

function void axi_sub_state::read_done(axi_sub_txn txn);
  foreach (m_r_q[i]) begin
    if (m_r_q[i] == txn) begin
      m_r_q.delete(i);
      return;
    end
  end
  `uvm_fatal(get_name(), $sformatf("Read %0s is not waiting for R.", txn.convert2string()))
endfunction : read_done
