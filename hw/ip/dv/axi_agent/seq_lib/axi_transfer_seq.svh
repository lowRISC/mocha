// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Send one AXI read or write burst on axi_mgr_agent::get_sequencer() and collect responses. Before
// randomizing, configure bus knobs manually or with set_bus_properties(); standalone sequences do
// not inherit them from the agent. Constraints enforce AMBA AXI H.c A3.4.1, A4.4 and A7.2.4. Write
// beats use m_beat_wdata, m_beat_wstrb and m_beat_wuser, with the addressed byte least significant;
// the sequence shifts them onto bus lanes. Empty m_beat_wdata regenerates all three with random
// data and full strobes. Later starts regenerate beats unchanged since body() created them;
// caller-supplied beats are sent as provided. Each start replaces m_requests and m_responses with
// its request and B response or R beats. Read data uses the same alignment and zeroes bytes outside
// the beat. has_full_transaction() reports reset-aborted bursts.

class axi_transfer_seq extends uvm_sequence;
  `uvm_object_utils(axi_transfer_seq)
  `uvm_declare_p_sequencer(axi_mgr_sequencer)

  // The largest AxSIZE that the bus can carry, as log2 of the transfer in bytes
  int unsigned m_max_size = $clog2(AxiMaxDataWidth / 8);

  // Constrain every burst byte to the address width and m_id/m_user to the ID/USER widths
  int unsigned m_addr_width = AxiMaxAddrWidth;
  int unsigned m_id_width   = AxiMaxIdWidth;
  int unsigned m_user_width = AxiMaxReqUserWidth;

  // AXI4-Lite uses one full-width transfer with AxLOCK and AxCACHE zero (AMBA AXI H.c B1.1)
  bit m_is_lite = 1'b0;

  // True if every request on this bus must carry the AxPROT value in m_fixed_prot
  bit                    m_has_fixed_prot = 1'b0;
  bit [AxiProtWidth-1:0] m_fixed_prot     = '0;

  // True if this bus permits an exclusive access
  bit m_allows_lock = 1'b1;

  // Percentage of generated beats with random strobes; other beats have full strobes
  int unsigned m_partial_strb_pct = 0;

  // B/R accept templates copied for each response (see axi_mgr_write_response_seq and
  // axi_mgr_read_data_seq)
  axi_mgr_write_response_seq m_b_accept;
  axi_mgr_read_data_seq      m_r_accept;

  rand bit m_write;

  // Request fields: AxID, AxADDR, AxLEN (beats minus one), AxSIZE (log2 bytes per beat), AxBURST,
  // AxLOCK, AxCACHE, AxPROT, AxQOS, AxREGION and AxUSER
  rand bit [AxiMaxIdWidth-1:0]      m_id;
  rand bit [AxiMaxAddrWidth-1:0]    m_addr;
  rand bit [AxiLenWidth-1:0]        m_len;
  rand bit [AxiSizeWidth-1:0]       m_size;
  rand burst_e                      m_burst;
  rand bit                          m_lock;
  rand bit [AxiCacheWidth-1:0]      m_cache;
  rand bit [AxiProtWidth-1:0]       m_prot;
  rand bit [AxiQosWidth-1:0]        m_qos;
  rand bit [AxiRegionWidth-1:0]     m_region;
  rand bit [AxiMaxReqUserWidth-1:0] m_user;

  // The write data, strobes and WUSER of each beat (see the comment at the top of the class)
  bit [AxiMaxDataWidth-1:0]     m_beat_wdata[$];
  bit [AxiMaxStrbWidth-1:0]     m_beat_wstrb[$];
  bit [AxiMaxDataUserWidth-1:0] m_beat_wuser[$];

  // Last generated beats, used to detect caller-supplied data
  local bit [AxiMaxDataWidth-1:0]     m_made_wdata[$];
  local bit [AxiMaxStrbWidth-1:0]     m_made_wstrb[$];
  local bit [AxiMaxDataUserWidth-1:0] m_made_wuser[$];

  axi_txn_request_item  m_requests[$];
  axi_txn_response_item m_responses[$];

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Configure m_max_size, m_addr_width, m_id_width, m_user_width and m_is_lite from the bus
  extern function void set_bus_properties(axi_vif_t vif);

  // Call after completion; false if reset prevented B or the final R beat
  extern function bit has_full_transaction();

  // Generate write data, strobes and WUSER. bus_bytes is in bytes; wuser_width is in bits.
  extern virtual protected function void make_wdata(int unsigned bus_bytes,
                                                    int unsigned wuser_width);

  // Return beat n's byte lanes [lower, upper] on a bus of bus_bytes bytes
  extern protected function void get_beat_lanes(input  int unsigned n,
                                                input  int unsigned bus_bytes,
                                                output int unsigned lower,
                                                output int unsigned upper);

  extern local function bit beats_are_made();

  extern local task send_write();
  extern local task send_read();

  extern constraint bus_properties_c;

  // All bytes through the transaction container's end must fit m_addr_width (H.c A3.4.1)
  extern constraint addr_width_c;

  extern constraint lite_c;

  // FIXED allows at most 16 beats; WRAP allows 2, 4, 8 or 16 (H.c A3.4.1). These and the next three
  // constraints match axi_txn_request_item.
  extern constraint burst_length_c;

  // An INCR burst does not cross a 4KB boundary (H.c A3.4.1)
  extern constraint no_4kb_boundary_crossing_c;

  // A WRAP burst starts at an address aligned to the size of each transfer (H.c A3.4.1)
  extern constraint wrap_alignment_c;

  // An exclusive access has a power of two total size of at most 128 bytes and an address aligned
  // to it (H.c A7.2.4)
  extern constraint exclusive_access_c;

  // AxCACHE is one of the memory type encodings (H.c A4.4, Table A4-5)
  extern constraint cache_encoding_c;

  // Default AxREGION to 0; region maps may override this soft constraint but must remain constant
  // per 4KB page (H.c A8.2.1, A9.3)
  extern constraint region_c;
endclass: axi_transfer_seq


function axi_transfer_seq::new(string name = "");
  super.new(name);
  m_b_accept = axi_mgr_write_response_seq::type_id::create("m_b_accept");
  m_r_accept = axi_mgr_read_data_seq::type_id::create("m_r_accept");
endfunction: new

task axi_transfer_seq::body();
  // Keep results local to this start
  m_requests.delete();
  m_responses.delete();
  if (m_write) begin
    send_write();
  end else begin
    send_read();
  end
endtask: body

function void axi_transfer_seq::set_bus_properties(axi_vif_t vif);
  int unsigned id_width   = vif.aw_if.id_w_width;
  int unsigned addr_width = vif.aw_if.addr_width;
  int unsigned user_width = vif.aw_if.user_req_width;

  if (vif.ar_if.id_r_width < id_width) begin
    id_width = vif.ar_if.id_r_width;
  end
  if (vif.ar_if.addr_width < addr_width) begin
    addr_width = vif.ar_if.addr_width;
  end
  if (vif.ar_if.user_req_width < user_width) begin
    user_width = vif.ar_if.user_req_width;
  end
  m_max_size   = $clog2(vif.w_if.data_width / 8);
  m_addr_width = addr_width;
  m_id_width   = id_width;
  m_user_width = user_width;
  m_is_lite    = vif.is_lite;
endfunction: set_bus_properties

function bit axi_transfer_seq::has_full_transaction();
  if (m_write) begin
    return m_responses.size() == 1;
  end
  return m_responses.size() == int'(m_len) + 1;
endfunction: has_full_transaction

function void axi_transfer_seq::make_wdata(int unsigned bus_bytes, int unsigned wuser_width);
  for (int unsigned n = 0; n <= m_len; n++) begin
    bit [AxiMaxDataWidth-1:0]     data;
    bit [AxiMaxStrbWidth-1:0]     strb;
    bit [AxiMaxDataUserWidth-1:0] user;
    int unsigned                  lower, upper;

    get_beat_lanes(n, bus_bytes, lower, upper);
    for (int unsigned i = 0; i < AxiMaxDataWidth; i += 32) begin
      data[i +: 32] = $urandom();
    end
    data &= (AxiMaxDataWidth'(1) << (8 * (upper - lower + 1))) - 1;
    strb = (AxiMaxStrbWidth'(1) << (upper - lower + 1)) - 1;
    if ($urandom_range(0, 99) < m_partial_strb_pct) begin
      for (int unsigned i = 0; i < AxiMaxStrbWidth; i += 32) begin
        strb[i +: 32] &= $urandom();
      end
    end

    for (int unsigned i = 0; i < AxiMaxDataUserWidth; i += 32) begin
      user[i +: 32] = $urandom();
    end
    user &= (AxiMaxDataUserWidth'(1) << wuser_width) - 1;

    m_beat_wdata.push_back(data);
    m_beat_wstrb.push_back(strb);
    m_beat_wuser.push_back(user);
  end
endfunction: make_wdata

function void axi_transfer_seq::get_beat_lanes(input  int unsigned n,
                                               input  int unsigned bus_bytes,
                                               output int unsigned lower,
                                               output int unsigned upper);
  bit [AxiMaxAddrWidth-1:0] beat_addr;

  axi_beat_lanes(m_addr, m_size, m_len, m_burst, bus_bytes, n, beat_addr, lower, upper);
endfunction: get_beat_lanes

function bit axi_transfer_seq::beats_are_made();
  if (m_made_wdata.size() == 0 ||
      m_beat_wdata.size() != m_made_wdata.size() ||
      m_beat_wstrb.size() != m_made_wstrb.size() ||
      m_beat_wuser.size() != m_made_wuser.size()) begin
    return 1'b0;
  end
  foreach (m_made_wdata[n]) begin
    if (m_beat_wdata[n] != m_made_wdata[n] ||
        m_beat_wstrb[n] != m_made_wstrb[n] ||
        m_beat_wuser[n] != m_made_wuser[n]) begin
      return 1'b0;
    end
  end
  return 1'b1;
endfunction: beats_are_made

task axi_transfer_seq::send_write();
  axi_mgr_write_burst_vseq vseq = axi_mgr_write_burst_vseq::type_id::create("write_vseq");
  int unsigned             bus_bytes = p_sequencer.m_vif.w_if.data_width / 8;

  // Regenerate all beat fields for reused generated data or empty write data
  if (m_beat_wdata.size() == 0 || beats_are_made()) begin
    m_beat_wdata.delete();
    m_beat_wstrb.delete();
    m_beat_wuser.delete();
    make_wdata(bus_bytes, p_sequencer.m_vif.w_if.user_data_width);
    m_made_wdata = m_beat_wdata;
    m_made_wstrb = m_beat_wstrb;
    m_made_wuser = m_beat_wuser;
  end else begin
    m_made_wdata.delete();
    m_made_wstrb.delete();
    m_made_wuser.delete();
  end
  if (m_beat_wdata.size() != int'(m_len) + 1 || m_beat_wstrb.size() != m_beat_wdata.size()) begin
    `uvm_fatal(get_full_name(),
               $sformatf({"A write with AxLEN = %0d needs %0d beats of data and strobes, but ",
                          "m_beat_wdata has %0d and m_beat_wstrb %0d."},
                         m_len, m_len + 1, m_beat_wdata.size(), m_beat_wstrb.size()))
  end

  // Shift each beat onto its bus lanes and mask strobes to those lanes (H.c A3.4.4)
  foreach (m_beat_wdata[n]) begin
    axi_write_data_item item = axi_write_data_item::type_id::create($sformatf("beat_%0d", n));
    int unsigned        lower, upper;

    get_beat_lanes(n, bus_bytes, lower, upper);
    item.m_data = m_beat_wdata[n] << (8 * lower);
    item.m_strb = (m_beat_wstrb[n] & ((AxiMaxStrbWidth'(1) << (upper - lower + 1)) - 1)) << lower;
    item.m_user = (n < m_beat_wuser.size()) ? m_beat_wuser[n] : '0;
    vseq.m_data_items.push_back(item);
  end

  vseq.set_sequencers(p_sequencer.m_write_request_sequencer,
                      p_sequencer.m_write_data_sequencer,
                      p_sequencer.m_write_response_sequencer);
  vseq.set_write_response_router(p_sequencer.m_write_response_router);
  vseq.m_b_accept = m_b_accept;

  if (!vseq.randomize() with {
        m_aw_req.m_id     == local::m_id;
        m_aw_req.m_addr   == local::m_addr;
        m_aw_req.m_len    == local::m_len;
        m_aw_req.m_size   == local::m_size;
        m_aw_req.m_burst  == local::m_burst;
        m_aw_req.m_lock   == local::m_lock;
        m_aw_req.m_cache  == local::m_cache;
        m_aw_req.m_prot   == local::m_prot;
        m_aw_req.m_qos    == local::m_qos;
        m_aw_req.m_region == local::m_region;
        m_aw_req.m_user   == local::m_user;
      }) begin
    `uvm_fatal(get_full_name(), "Failed to randomise the write burst.")
  end

  vseq.start(null, this);

  m_requests.push_back(vseq.m_aw_req);
  if (vseq.rsp.m_write_response != null) begin
    axi_txn_response_item rsp_item = axi_txn_response_item::type_id::create("b_rsp");

    rsp_item.m_write = 1'b1;
    rsp_item.m_id    = vseq.rsp.m_write_response.m_id;
    rsp_item.m_resp  = vseq.rsp.m_write_response.m_resp;
    rsp_item.m_last  = 1'b1;
    rsp_item.m_user  = vseq.rsp.m_write_response.m_user;
    m_responses.push_back(rsp_item);
  end
endtask: send_write

task axi_transfer_seq::send_read();
  axi_mgr_read_burst_vseq vseq = axi_mgr_read_burst_vseq::type_id::create("read_vseq");
  int unsigned            bus_bytes = p_sequencer.m_vif.r_if.data_width / 8;

  vseq.set_sequencers(p_sequencer.m_read_request_sequencer, p_sequencer.m_read_data_sequencer);
  vseq.set_read_response_router(p_sequencer.m_read_response_router);
  vseq.m_r_accept = m_r_accept;

  if (!vseq.randomize() with {
        m_ar_req.m_id     == local::m_id;
        m_ar_req.m_addr   == local::m_addr;
        m_ar_req.m_len    == local::m_len;
        m_ar_req.m_size   == local::m_size;
        m_ar_req.m_burst  == local::m_burst;
        m_ar_req.m_lock   == local::m_lock;
        m_ar_req.m_cache  == local::m_cache;
        m_ar_req.m_prot   == local::m_prot;
        m_ar_req.m_qos    == local::m_qos;
        m_ar_req.m_region == local::m_region;
        m_ar_req.m_user   == local::m_user;
      }) begin
    `uvm_fatal(get_full_name(), "Failed to randomise the read burst.")
  end

  vseq.start(null, this);

  m_requests.push_back(vseq.m_ar_req);
  foreach (vseq.rsp.m_read_data[n]) begin
    axi_txn_response_item rsp_item;
    int unsigned          lower, upper;

    rsp_item = axi_txn_response_item::type_id::create($sformatf("r_rsp_%0d", n));
    get_beat_lanes(n, bus_bytes, lower, upper);
    rsp_item.m_write = 1'b0;
    rsp_item.m_id    = vseq.rsp.m_read_data[n].m_id;
    rsp_item.m_rdata = (vseq.rsp.m_read_data[n].m_data >> (8 * lower)) &
                       ((AxiMaxDataWidth'(1) << (8 * (upper - lower + 1))) - 1);
    rsp_item.m_resp  = vseq.rsp.m_read_data[n].m_resp;
    rsp_item.m_last  = vseq.rsp.m_read_data[n].m_last;
    rsp_item.m_user  = vseq.rsp.m_read_data[n].m_user;
    m_responses.push_back(rsp_item);
  end
endtask: send_read

constraint axi_transfer_seq::bus_properties_c {
  m_size <= m_max_size;
  (m_id >> m_id_width) == 0;
  (m_user >> m_user_width) == 0;
  m_has_fixed_prot -> m_prot == m_fixed_prot;
  !m_allows_lock -> !m_lock;
}

constraint axi_transfer_seq::addr_width_c {
  (m_addr >> m_addr_width) == 0;
  (m_burst == BurstIncr) ->
    (((((m_addr >> m_size) + m_len + 1) << m_size) - 1) >> m_addr_width) == 0;
  (m_burst == BurstWrap) -> ((m_addr | (((m_len + 1) << m_size) - 1)) >> m_addr_width) == 0;
  (m_burst == BurstFixed) -> ((m_addr | ((1 << m_size) - 1)) >> m_addr_width) == 0;
}

constraint axi_transfer_seq::lite_c {
  m_is_lite -> m_len == 0;
  m_is_lite -> m_size == m_max_size;
  m_is_lite -> m_burst == BurstIncr;
  m_is_lite -> !m_lock;
  m_is_lite -> m_cache == 4'b0000;
}

constraint axi_transfer_seq::burst_length_c {
  (m_burst == BurstFixed) -> (m_len <= 15);
  (m_burst == BurstWrap) -> (m_len inside {1, 3, 7, 15});
}

constraint axi_transfer_seq::no_4kb_boundary_crossing_c {
  (m_burst == BurstIncr) ->
    (((((m_addr >> m_size) + m_len + 1) << m_size) - 1) >> 12) == (m_addr >> 12);
}

constraint axi_transfer_seq::wrap_alignment_c {
  (m_burst == BurstWrap) -> (m_addr & ((1 << m_size) - 1)) == '0;
}

constraint axi_transfer_seq::exclusive_access_c {
  m_lock -> m_len inside {0, 1, 3, 7, 15};
  m_lock -> ((m_len + 1) << m_size) <= 128;
  m_lock -> (m_addr & (((m_len + 1) << m_size) - 1)) == '0;
}

constraint axi_transfer_seq::cache_encoding_c {
  m_cache inside {4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0110,
                  4'b0111, 4'b1010, 4'b1011, 4'b1110, 4'b1111};
}

constraint axi_transfer_seq::region_c {
  soft m_region == '0;
}
