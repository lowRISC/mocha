// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// AXI agent self-test scoreboard. Predict subordinate responses from accepted policies, error
// regions and per-ID exclusive monitors, or from the pulp_axi link description. Predict read data
// from an independent byte memory built from writes. Compare manager and subordinate observations
// across direct links, crossbar routing and ID widening, or per-beat AXI4-Lite bridging. Compare
// sequence results with manager observations per direction and ID, preserving same-ID order (AMBA
// AXI H.c A5.1). At test end, compare subordinate memory and require every transaction and record
// to be complete and paired.

class axi_agent_scoreboard extends dv_base_scoreboard #(
    .CFG_T(axi_agent_env_cfg),
    .COV_T(axi_agent_env_cov)
  );
  `uvm_component_utils(axi_agent_scoreboard)

  typedef bit [AxiMaxIdWidth-1:0]   id_t;
  typedef bit [AxiMaxAddrWidth-1:0] addr_t;

  // Monitored AW/AR requests and completed transactions at every endpoint, plus subordinate
  // acceptance records with policies
  uvm_tlm_analysis_fifo #(axi_mon_item) m_mgr_request_fifos[];
  uvm_tlm_analysis_fifo #(axi_mon_item) m_mgr_txn_fifos[];
  uvm_tlm_analysis_fifo #(axi_mon_item) m_sub_request_fifos[];
  uvm_tlm_analysis_fifo #(axi_mon_item) m_sub_txn_fifos[];
  uvm_tlm_analysis_fifo #(axi_sub_txn)  m_sub_accept_fifos[];

  // Completed manager sequence records
  uvm_tlm_analysis_fifo #(axi_agent_mgr_txn) m_mgr_driver_txn_fifo;

  // Requests at each end that have not completed, per direction (1 for writes) and ID, oldest first
  local axi_mon_item m_mgr_open[int unsigned][2][id_t][$];
  local axi_mon_item m_sub_open[int unsigned][2][id_t][$];

  // Whether read data prediction was on when the subordinate end saw each open read request, per
  // ID, oldest first. A read requested before then may overlap earlier writes (H.c A6.1).
  local bit m_sub_read_predict[int unsigned][id_t][$];

  // Monitored transactions and sequence records waiting to be paired, per manager end, direction
  // and ID
  local axi_mon_item      m_mon_txns[int unsigned][2][id_t][$];
  local axi_agent_mgr_txn m_drv_txns[int unsigned][2][id_t][$];

  // Unanswered subordinate acceptances per direction and ID, and sequence policies in assignment
  // order
  local axi_sub_txn      m_accepts[int unsigned][2][id_t][$];
  local axi_sub_rsp_item m_applied[int unsigned][$];

  // When each subordinate agent last accepted a write
  local time m_last_write_accept[int unsigned];

  // Unpaired completions from both sides, keyed by subordinate endpoint, direction and subordinate
  // ID. Manager completions retain their endpoint.
  local axi_mon_item m_link_mgr[int unsigned][2][id_t][$];
  local int unsigned m_link_mgr_idx[int unsigned][2][id_t][$];
  local axi_mon_item m_link_sub[int unsigned][2][id_t][$];

  // Per direction on the bridge: unpaired manager bursts in order, unclaimed AXI4-Lite completions
  // and total completion count
  local axi_agent_bridge_burst m_bridge_bursts[2][$];
  local axi_mon_item           m_bridge_spares[2][$];
  local int unsigned           m_bridge_spare_nums[2][$];
  local int unsigned           m_bridge_num_done[2];

  // Reference memory, one entry per written byte
  local bit [7:0] m_ref[addr_t];

  // Unknown bytes from reset-aborted writes or error writes that may have updated memory
  local bit m_unknown[addr_t];

  // Exclusive monitor per subordinate and ID (H.c A7.2.3): the exclusive read, set when the
  // subordinate accepts it, until a write to its bytes. Writes to those bytes in flight at that
  // point are unordered against the read (A6.1), so a matching exclusive write may then fail.
  typedef struct {
    axi_txn_request_item req;
    axi_sub_txn          unordered[$];
  } excl_mon_t;
  local excl_mon_t m_excl[int unsigned][id_t];

  // The scoreboard's own activity counts (see get_count)
  local int unsigned m_counts[string];

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void check_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);

  // Class specific methods

  // On reset release, invalidate bytes of open writes and discard all transactions in flight
  extern virtual function void reset(string kind = "HARD");

  // Return a probe or scoreboard activity count by name (see axi_agent_probe_if)
  extern function int unsigned get_count(string name);

  extern local task process_mgr_requests(int unsigned mgr);
  extern local task process_mgr_txns(int unsigned mgr);
  extern local task process_sub_requests(int unsigned sub);
  extern local task process_sub_txns(int unsigned sub);
  extern local task process_sub_accepts(int unsigned sub);
  extern local task process_mgr_driver_txns();

  // At each clock edge, compare the bridge write bursts that are complete apart from beats with no
  // strobes
  extern local task process_bridge_suppression();

  extern local function void count(string name, int unsigned n = 1);

  extern local function bit [AxiMaxDataWidth-1:0] low_bits(int unsigned width);

  extern local function bit is_write(axi_mon_item item);
  extern local function id_t get_id(axi_mon_item item);

  // Close the endpoint's oldest request matching direction and ID. Report unmatched completions and
  // check beat count against AxLEN. is_sub selects a subordinate endpoint.
  extern local function void close_request(bit is_sub, int unsigned idx, axi_mon_item item);

  // Handle a request or a completed transaction at a manager end
  extern local function void on_mgr_request(int unsigned mgr, axi_mon_item item);
  extern local function void on_mgr_txn(int unsigned mgr, axi_mon_item item);

  // Handle a request, an acceptance or a completed transaction at a subordinate end
  extern local function void on_sub_request(int unsigned sub, axi_mon_item item);
  extern local function void on_sub_accept(int unsigned sub, axi_sub_txn rec);
  extern local function void on_sub_txn(int unsigned sub, axi_mon_item item);

  // Return the effective burst: unchanged for AXI4, one full-width transfer for AXI4-Lite (H.c
  // B1.1.1)
  extern local function void sub_burst(bit is_lite, logic [AxiLenWidth-1:0] len_in,
                                       logic [AxiSizeWidth-1:0] size_in,
                                       logic [AxiBurstWidth-1:0] burst_in,
                                       output bit [AxiLenWidth-1:0] len,
                                       output bit [AxiSizeWidth-1:0] size,
                                       output bit [AxiBurstWidth-1:0] burst);

  // Return whether beat n of a burst touches a byte in the error region of a subordinate agent
  extern local function bit beat_in_err_region(axi_sub_agent_cfg sub_cfg, addr_t addr,
                                               bit [AxiSizeWidth-1:0] size,
                                               bit [AxiLenWidth-1:0] len,
                                               bit [AxiBurstWidth-1:0] burst, int unsigned n);

  // Predict and check a subordinate-agent completion from its accepted policy, then update
  // reference memory. predict selects read data checking.
  extern local function void check_agent_write(int unsigned sub, axi_mon_write_item item,
                                               axi_sub_txn rec);
  extern local function void check_agent_read(int unsigned sub, axi_mon_read_item item,
                                              axi_sub_txn rec, bit predict);

  // Predict and check a pulp_axi completion from the link description, then update reference
  // memory. predict selects read data checking.
  extern local function void check_model_write(axi_mon_write_item item);
  extern local function void check_model_read(axi_mon_read_item item, bit predict);

  // Return the address-based pulp_axi error for beat n, where writes count only strobed bytes
  extern local function bit model_addr_error(addr_t addr, bit [AxiSizeWidth-1:0] size,
                                             bit [AxiLenWidth-1:0] len,
                                             bit [AxiBurstWidth-1:0] burst, int unsigned n,
                                             bit is_write, logic [AxiMaxStrbWidth-1:0] strb,
                                             output bit [AxiRespWidth-1:0] resp);

  // Return the byte that a subordinate agent should read at addr, and whether it is known
  extern local function bit [7:0] expected_byte(int unsigned sub, addr_t addr, output bit known);

  // Return the burst's byte range [lo, hi] from its transaction container, starting at the address
  // for unaligned INCR (H.c A3.4.1)
  extern local function void get_range(addr_t addr, bit [AxiSizeWidth-1:0] size,
                                       bit [AxiLenWidth-1:0] len, bit [AxiBurstWidth-1:0] burst,
                                       output addr_t lo, output addr_t hi);

  // Set or clear the ID's monitor when the subordinate accepts an exclusive read. An exclusive read
  // with an error leaves the monitor empty (A7.2.1).
  extern local function void set_excl(int unsigned sub, axi_sub_txn rec);

  // Match exclusive writes to their ID's monitored read using all AXI4 attributes in H.c A7.2.4,
  // and report whether a write unordered against that read was in flight
  extern local function bit excl_matches(int unsigned sub, axi_mon_write_item item,
                                         output bit unordered);

  // Invalidate monitors whose bytes a write changed, unless the write was unordered against them
  extern local function void clear_excl(int unsigned sub, addr_t addr, axi_sub_txn rec);

  // Pair and compare completions across the link
  extern local function void pair_link(int unsigned sub, bit dir, id_t id);
  extern local function void compare_link(axi_mon_item mgr_item, int unsigned mgr,
                                          axi_mon_item sub_item, int unsigned sub);

  // Check a manager-end transaction that the crossbar routes to no subordinate
  extern local function void check_decode_error(int unsigned mgr, axi_mon_item item);

  // Match an AXI4-Lite completion, numbered num in its direction, to a waiting burst beat by
  // address. Return 0 if none matches.
  extern local function bit bridge_place(bit dir, axi_mon_item xfer, int unsigned num);

  // Compare and remove bridge bursts once the manager burst and all AXI4-Lite transfers complete.
  // With may_suppress, also take a write burst whose beats without a transfer have no strobes, once
  // its B is in an earlier time step, or at any time with at_end (H.c B1.1.3, B1.3.1).
  extern local function void bridge_complete(bit dir, bit may_suppress = 1'b0, bit at_end = 1'b0);

  // Compare a manager-end burst with the AXI4-Lite transfers that the bridge made of it
  extern local function void compare_bridge(axi_agent_bridge_burst burst);

  // Pair records with monitored transactions and compare them
  extern local function void compare_mgr_driver_txns(int unsigned mgr, bit dir, id_t id);
  extern local function void compare_txn(axi_agent_mgr_txn txn, axi_mon_item item);

  // Check that subordinate transactions received sequence policies in supply order
  extern local function void check_applied_policies();

  // Compare what the bus wrote with what each subordinate agent holds
  extern local function void check_memory();

  // Check that every W burst on each bus of the link had its AW request and ended with WLAST
  extern local function void check_w_matched();
endclass : axi_agent_scoreboard


function axi_agent_scoreboard::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi_agent_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);

  m_mgr_request_fifos = new[cfg.m_link.m_num_mgrs];
  m_mgr_txn_fifos     = new[cfg.m_link.m_num_mgrs];
  foreach (m_mgr_txn_fifos[i]) begin
    m_mgr_request_fifos[i] = new($sformatf("m_mgr_request_fifos[%0d]", i), this);
    m_mgr_txn_fifos[i]     = new($sformatf("m_mgr_txn_fifos[%0d]", i), this);
  end
  m_sub_request_fifos = new[cfg.m_link.m_num_subs];
  m_sub_txn_fifos     = new[cfg.m_link.m_num_subs];
  m_sub_accept_fifos  = new[cfg.m_link.m_num_subs];
  foreach (m_sub_txn_fifos[i]) begin
    m_sub_request_fifos[i] = new($sformatf("m_sub_request_fifos[%0d]", i), this);
    m_sub_txn_fifos[i]     = new($sformatf("m_sub_txn_fifos[%0d]", i), this);
    m_sub_accept_fifos[i]  = new($sformatf("m_sub_accept_fifos[%0d]", i), this);
  end
  m_mgr_driver_txn_fifo = new("m_mgr_driver_txn_fifo", this);
endfunction : build_phase

task axi_agent_scoreboard::run_phase(uvm_phase phase);
  fork
    super.run_phase(phase);
    process_mgr_driver_txns();
  join_none
  if (cfg.m_link.m_kind == axi_agent_link_cfg::LinkLiteBridge) begin
    fork
      process_bridge_suppression();
    join_none
  end
  foreach (m_mgr_txn_fifos[i]) begin
    automatic int unsigned mgr = i;

    fork
      process_mgr_requests(mgr);
      process_mgr_txns(mgr);
    join_none
  end
  foreach (m_sub_txn_fifos[i]) begin
    automatic int unsigned sub = i;

    fork
      process_sub_requests(sub);
      process_sub_txns(sub);
      process_sub_accepts(sub);
    join_none
  end
endtask : run_phase

function void axi_agent_scoreboard::count(string name, int unsigned n = 1);
  if (!m_counts.exists(name)) begin
    m_counts[name] = 0;
  end
  m_counts[name] += n;
endfunction : count

function bit [AxiMaxDataWidth-1:0] axi_agent_scoreboard::low_bits(int unsigned width);
  return (AxiMaxDataWidth'(1) << width) - 1;
endfunction : low_bits

function bit axi_agent_scoreboard::is_write(axi_mon_item item);
  return item.get_dir() == AXI_WRITE;
endfunction : is_write

function axi_agent_scoreboard::id_t axi_agent_scoreboard::get_id(axi_mon_item item);
  return id_t'(item.get_id());
endfunction : get_id

task axi_agent_scoreboard::process_mgr_requests(int unsigned mgr);
  forever begin
    axi_mon_item item;

    m_mgr_request_fifos[mgr].get(item);
    on_mgr_request(mgr, item);
  end
endtask : process_mgr_requests

task axi_agent_scoreboard::process_mgr_txns(int unsigned mgr);
  forever begin
    axi_mon_item item;

    m_mgr_txn_fifos[mgr].get(item);
    on_mgr_txn(mgr, item);
  end
endtask : process_mgr_txns

task axi_agent_scoreboard::process_sub_requests(int unsigned sub);
  forever begin
    axi_mon_item item;

    m_sub_request_fifos[sub].get(item);
    on_sub_request(sub, item);
  end
endtask : process_sub_requests

task axi_agent_scoreboard::process_sub_txns(int unsigned sub);
  forever begin
    axi_mon_item item;

    m_sub_txn_fifos[sub].get(item);
    on_sub_txn(sub, item);
  end
endtask : process_sub_txns

task axi_agent_scoreboard::process_sub_accepts(int unsigned sub);
  forever begin
    axi_sub_txn rec;

    m_sub_accept_fifos[sub].get(rec);
    on_sub_accept(sub, rec);
  end
endtask : process_sub_accepts

task axi_agent_scoreboard::process_mgr_driver_txns();
  forever begin
    axi_agent_mgr_txn txn;
    id_t              id;

    m_mgr_driver_txn_fifo.get(txn);
    if (!cfg.en_scb || !txn.m_complete) begin
      continue;
    end
    id = txn.m_req.m_id;
    m_drv_txns[txn.m_mgr_idx][txn.m_is_write][id].push_back(txn);
    compare_mgr_driver_txns(txn.m_mgr_idx, txn.m_is_write, id);
  end
endtask : process_mgr_driver_txns

task axi_agent_scoreboard::process_bridge_suppression();
  // A bridge takes every child B before it sends the burst's B (H.c B1.3.1), so a transfer still
  // missing at the next edge was suppressed
  forever begin
    @(posedge cfg.clk_rst_vif.clk);
    bridge_complete(1'b1, 1'b1);
  end
endtask : process_bridge_suppression

function void axi_agent_scoreboard::close_request(bit is_sub, int unsigned idx, axi_mon_item item);
  bit                dir = is_write(item);
  id_t               id = get_id(item);
  string             where = $sformatf("%0s end %0d", is_sub ? "subordinate" : "manager", idx);
  bit                found = 1'b0;
  axi_mon_write_item witem;
  axi_mon_read_item  ritem;

  if (is_sub) begin
    if (m_sub_open.exists(idx) && m_sub_open[idx][dir].exists(id) &&
        m_sub_open[idx][dir][id].size() > 0) begin
      void'(m_sub_open[idx][dir][id].pop_front());
      found = 1'b1;
    end
  end else begin
    if (m_mgr_open.exists(idx) && m_mgr_open[idx][dir].exists(id) &&
        m_mgr_open[idx][dir][id].size() > 0) begin
      void'(m_mgr_open[idx][dir][id].pop_front());
      found = 1'b1;
    end
  end
  if (!found) begin
    `uvm_error(get_full_name(), $sformatf("%0s completed at %0s, which never saw its request.",
                                          item.convert2string(), where))
  end

  // Every burst carries AxLEN + 1 beats (H.c A3.4.1), even one that ends in an error (A3.4.5)
  if ($cast(witem, item) && witem.m_wdata.size() != int'(witem.m_awlen) + 1) begin
    `uvm_error(get_full_name(), $sformatf("%0s at %0s carried %0d W beats, not AWLEN + 1.",
                                          item.convert2string(), where, witem.m_wdata.size()))
  end
  if ($cast(ritem, item) && ritem.m_rdata.size() != int'(ritem.m_arlen) + 1) begin
    `uvm_error(get_full_name(), $sformatf("%0s at %0s carried %0d R beats, not ARLEN + 1.",
                                          item.convert2string(), where, ritem.m_rdata.size()))
  end

  // Count observed bursts over 16 beats and at the 256-beat INCR limit (H.c A3.4.1)
  if (is_sub) begin
    int unsigned beats = (witem != null) ? witem.m_wdata.size() : ritem.m_rdata.size();

    if (beats > 16) begin
      count(dir ? "long_writes" : "long_reads");
    end
    if (beats == 256) begin
      count(dir ? "max_len_writes" : "max_len_reads");
    end
  end
endfunction : close_request

function void axi_agent_scoreboard::on_mgr_request(int unsigned mgr, axi_mon_item item);
  bit                dir = is_write(item);
  axi_mon_write_item witem;
  axi_mon_read_item  ritem;

  m_mgr_open[mgr][dir][get_id(item)].push_back(item);

  if (cfg.m_has_fixed_prot) begin
    logic [AxiProtWidth-1:0] prot;

    if ($cast(witem, item)) begin
      prot = witem.m_awprot;
    end else if ($cast(ritem, item)) begin
      prot = ritem.m_arprot;
    end
    count("fixed_prot_checked");
    if (prot !== cfg.m_fixed_prot) begin
      `uvm_error(get_full_name(), $sformatf("%0s at manager end %0d has AxPROT %0d, not %0d.",
                                            item.convert2string(), mgr, prot, cfg.m_fixed_prot))
    end
  end

  // The bridge makes an AXI4-Lite transfer to the address of each beat (H.c A3.4.2, B1.3.1)
  if (cfg.m_link.m_kind == axi_agent_link_cfg::LinkLiteBridge) begin
    axi_agent_bridge_burst  burst = axi_agent_bridge_burst::type_id::create("burst");
    int unsigned            bus_bytes = cfg.m_data_width / 8;
    bit [AxiLenWidth-1:0]   len;
    bit [AxiSizeWidth-1:0]  size;
    bit [AxiBurstWidth-1:0] burst_type;
    axi_mon_item            spares[$];
    int unsigned            spare_nums[$];

    if ($cast(witem, item)) begin
      len        = witem.m_awlen;
      size       = witem.m_awsize;
      burst_type = witem.m_awburst;
    end else if ($cast(ritem, item)) begin
      len        = ritem.m_arlen;
      size       = ritem.m_arsize;
      burst_type = ritem.m_arburst;
    end
    burst.m_req = item;
    for (int unsigned n = 0; n <= int'(len); n++) begin
      addr_t       beat_addr;
      int unsigned lower, upper;

      beat_lanes(item.get_addr(), size, len, burst_type, bus_bytes, n, beat_addr, lower, upper);
      burst.m_beat_addrs.push_back(beat_addr);
      burst.m_transfers.push_back(null);
      burst.m_transfer_nums.push_back(0);
    end
    m_bridge_bursts[dir].push_back(burst);

    // Give the new burst any transfers that completed before its request was seen
    spares     = m_bridge_spares[dir];
    spare_nums = m_bridge_spare_nums[dir];
    m_bridge_spares[dir].delete();
    m_bridge_spare_nums[dir].delete();
    foreach (spares[i]) begin
      if (!bridge_place(dir, spares[i], spare_nums[i])) begin
        m_bridge_spares[dir].push_back(spares[i]);
        m_bridge_spare_nums[dir].push_back(spare_nums[i]);
      end
    end
  end
endfunction : on_mgr_request

function void axi_agent_scoreboard::on_mgr_txn(int unsigned mgr, axi_mon_item item);
  bit  dir = is_write(item);
  id_t id = get_id(item);
  int  sub;
  id_t sub_id;

  close_request(1'b0, mgr, item);
  if (!cfg.en_scb) begin
    return;
  end

  if (cfg.m_mgr_records) begin
    m_mon_txns[mgr][dir][id].push_back(item);
    compare_mgr_driver_txns(mgr, dir, id);
  end

  case (cfg.m_link.m_kind)
    axi_agent_link_cfg::LinkLiteBridge: begin
      // Same-ID transactions complete in request order (H.c A5.1). Wait for both sides. The final
      // AXI4-Lite transfer may complete at the same edge.
      bit found = 1'b0;

      foreach (m_bridge_bursts[dir][i]) begin
        axi_agent_bridge_burst burst = m_bridge_bursts[dir][i];

        if (burst.m_txn == null && get_id(burst.m_req) == id) begin
          burst.m_txn      = item;
          burst.m_txn_time = $realtime;
          found = 1'b1;
          break;
        end
      end
      if (!found) begin
        `uvm_error(get_full_name(), $sformatf("%0s completed at the bridge with no request.",
                                              item.convert2string()))
      end
      bridge_complete(dir);
    end
    axi_agent_link_cfg::LinkXbar: begin
      // The crossbar puts the index of the manager port above the manager's ID bits
      sub    = cfg.m_link.route(item.get_addr());
      sub_id = (id_t'(mgr) << XbarMgrIdBits) | (id & low_bits(XbarMgrIdBits));
      if (sub < 0) begin
        check_decode_error(mgr, item);
      end else begin
        m_link_mgr[sub][dir][sub_id].push_back(item);
        m_link_mgr_idx[sub][dir][sub_id].push_back(mgr);
        pair_link(sub, dir, sub_id);
      end
    end
    default: begin
      m_link_mgr[0][dir][id].push_back(item);
      m_link_mgr_idx[0][dir][id].push_back(mgr);
      pair_link(0, dir, id);
    end
  endcase
endfunction : on_mgr_txn

function void axi_agent_scoreboard::on_sub_request(int unsigned sub, axi_mon_item item);
  m_sub_open[sub][is_write(item)][get_id(item)].push_back(item);
  if (!is_write(item)) begin
    m_sub_read_predict[sub][get_id(item)].push_back(cfg.m_link.m_predict_reads);
  end

  if (cfg.m_link.m_kind == axi_agent_link_cfg::LinkXbar) begin
    bit busy_elsewhere = 1'b0;

    count($sformatf("sub%0d_requests", sub));
    if ((get_id(item) >> XbarMgrIdBits) != 0) begin
      count("widened_ids");
    end
    foreach (m_sub_open[s]) begin
      if (s == sub) begin
        continue;
      end
      for (int dir = 0; dir < 2; dir++) begin
        foreach (m_sub_open[s][dir][id]) begin
          busy_elsewhere |= (m_sub_open[s][dir][id].size() > 0);
        end
      end
    end
    if (busy_elsewhere) begin
      count("concurrent_subordinates");
    end
  end
endfunction : on_sub_request

function void axi_agent_scoreboard::on_sub_accept(int unsigned sub, axi_sub_txn rec);
  m_accepts[sub][rec.m_is_write][id_t'(rec.m_req.m_id)].push_back(rec);
  if (rec.m_policy_from_seq) begin
    m_applied[sub].push_back(rec.m_policy);
  end
  if (!rec.m_is_write) begin
    set_excl(sub, rec);
  end

  // AW and AR accepted at the same edge
  if (rec.m_is_write) begin
    m_last_write_accept[sub] = $time;
  end else if (m_last_write_accept.exists(sub) && m_last_write_accept[sub] == $time) begin
    count("same_edge_accepts");
  end
endfunction : on_sub_accept

function void axi_agent_scoreboard::on_sub_txn(int unsigned sub, axi_mon_item item);
  bit                dir = is_write(item);
  id_t               id = get_id(item);
  axi_sub_txn        rec;
  axi_mon_write_item witem;
  axi_mon_read_item  ritem;
  bit                predict = 1'b0;

  close_request(1'b1, sub, item);
  if (!dir && m_sub_read_predict.exists(sub) && m_sub_read_predict[sub].exists(id) &&
      m_sub_read_predict[sub][id].size() > 0) begin
    predict = m_sub_read_predict[sub][id].pop_front();
  end

  if (cfg.m_link.m_sub_is_agent) begin
    if (m_accepts.exists(sub) && m_accepts[sub][dir].exists(id) &&
        m_accepts[sub][dir][id].size() > 0) begin
      rec = m_accepts[sub][dir][id].pop_front();
    end else begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s completed at subordinate end %0d, whose agent never accepted it.",
                           item.convert2string(), sub))
    end
  end
  if (!cfg.en_scb) begin
    return;
  end

  if (rec != null) begin
    axi_txn_request_item req = rec.m_req;
    bit                  same;

    if ($cast(witem, item)) begin
      same = (witem.m_awaddr === req.m_addr && witem.m_awlen === req.m_len &&
              witem.m_awsize === req.m_size && witem.m_awburst === req.m_burst &&
              witem.m_awlock === req.m_lock && witem.m_awcache === req.m_cache &&
              witem.m_awprot === req.m_prot && witem.m_awregion === req.m_region);
    end else if ($cast(ritem, item)) begin
      same = (ritem.m_araddr === req.m_addr && ritem.m_arlen === req.m_len &&
              ritem.m_arsize === req.m_size && ritem.m_arburst === req.m_burst &&
              ritem.m_arlock === req.m_lock && ritem.m_arcache === req.m_cache &&
              ritem.m_arprot === req.m_prot && ritem.m_arregion === req.m_region);
    end
    if (!same) begin
      `uvm_error(get_full_name(),
                 $sformatf("Subordinate end %0d published the acceptance of %0s for %0s.", sub,
                           rec.convert2string(), item.convert2string()))
    end
  end

  if ($cast(witem, item)) begin
    if (rec != null) begin
      check_agent_write(sub, witem, rec);
    end else if (!cfg.m_link.m_sub_is_agent) begin
      check_model_write(witem);
    end
  end else if ($cast(ritem, item)) begin
    if (rec != null) begin
      check_agent_read(sub, ritem, rec, predict);
    end else if (!cfg.m_link.m_sub_is_agent) begin
      check_model_read(ritem, predict);
    end
  end

  if (cfg.m_link.m_kind == axi_agent_link_cfg::LinkLiteBridge) begin
    int unsigned num = m_bridge_num_done[dir]++;

    if (!bridge_place(dir, item, num)) begin
      m_bridge_spares[dir].push_back(item);
      m_bridge_spare_nums[dir].push_back(num);
    end
    bridge_complete(dir);
  end else begin
    m_link_sub[sub][dir][id].push_back(item);
    pair_link(sub, dir, id);
  end
endfunction : on_sub_txn

function void axi_agent_scoreboard::reset(string kind = "HARD");
  super.reset(kind);

  // A reset-aborted write may have changed memory
  foreach (m_sub_open[sub]) begin
    foreach (m_sub_open[sub][1][id]) begin
      foreach (m_sub_open[sub][1][id][i]) begin
        axi_mon_write_item item;
        addr_t             lo, hi;

        if (!$cast(item, m_sub_open[sub][1][id][i])) begin
          `uvm_fatal(get_full_name(), "An open write is not an axi_mon_write_item.")
        end
        // Use offsets from lo to avoid wrapping past the highest address
        get_range(item.m_awaddr, item.m_awsize, item.m_awlen, item.m_awburst, lo, hi);
        for (addr_t offset = 0; offset <= hi - lo; offset++) begin
          m_unknown[lo + offset] = 1'b1;
        end
        count("writes_cut_by_reset");
      end
    end
  end

  // Compare bridge write bursts that completed before the reset, apart from suppressed beats
  bridge_complete(1'b1, 1'b1);

  // Reset discards outstanding transactions and exclusive monitors
  m_mgr_open.delete();
  m_sub_open.delete();
  m_sub_read_predict.delete();
  m_accepts.delete();
  m_link_mgr.delete();
  m_link_mgr_idx.delete();
  m_link_sub.delete();
  for (int dir = 0; dir < 2; dir++) begin
    m_bridge_bursts[dir].delete();
    m_bridge_spares[dir].delete();
    m_bridge_spare_nums[dir].delete();
  end
  m_excl.delete();
endfunction : reset

function void axi_agent_scoreboard::get_range(addr_t addr, bit [AxiSizeWidth-1:0] size,
                                              bit [AxiLenWidth-1:0] len,
                                              bit [AxiBurstWidth-1:0] burst,
                                              output addr_t lo, output addr_t hi);
  int unsigned nbytes = 1 << size;
  int unsigned total = nbytes * (len + 1);

  case (burst)
    axi_pkg::BURST_FIXED: begin
      lo = addr;
      hi = (addr / nbytes) * nbytes + nbytes - 1;
    end
    axi_pkg::BURST_WRAP: begin
      lo = (addr / total) * total;
      hi = lo + total - 1;
    end
    default: begin
      lo = addr;
      hi = (addr / nbytes) * nbytes + total - 1;
    end
  endcase
endfunction : get_range

function void axi_agent_scoreboard::sub_burst(bit is_lite, logic [AxiLenWidth-1:0] len_in,
                                              logic [AxiSizeWidth-1:0] size_in,
                                              logic [AxiBurstWidth-1:0] burst_in,
                                              output bit [AxiLenWidth-1:0] len,
                                              output bit [AxiSizeWidth-1:0] size,
                                              output bit [AxiBurstWidth-1:0] burst);
  if (is_lite) begin
    len   = 0;
    size  = $clog2(cfg.m_data_width / 8);
    burst = axi_pkg::BURST_INCR;
  end else begin
    len   = len_in;
    size  = size_in;
    burst = burst_in;
  end
endfunction : sub_burst

function bit axi_agent_scoreboard::beat_in_err_region(axi_sub_agent_cfg sub_cfg, addr_t addr,
                                                      bit [AxiSizeWidth-1:0] size,
                                                      bit [AxiLenWidth-1:0] len,
                                                      bit [AxiBurstWidth-1:0] burst,
                                                      int unsigned n);
  int unsigned bus_bytes = cfg.m_data_width / 8;
  addr_t       beat_addr;
  int unsigned lower, upper;

  beat_lanes(addr, size, len, burst, bus_bytes, n, beat_addr, lower, upper);
  for (int unsigned lane = lower; lane <= upper; lane++) begin
    if (sub_cfg.addr_is_error(beat_addr - (beat_addr % bus_bytes) + lane)) begin
      return 1'b1;
    end
  end
  return 1'b0;
endfunction : beat_in_err_region

function bit [7:0] axi_agent_scoreboard::expected_byte(int unsigned sub, addr_t addr,
                                                       output bit known);
  known = !m_unknown.exists(addr);

  // Mapped memories drop unmapped writes, and unmapped reads return the subordinate's default byte
  if (cfg.m_mapped_mem && !(addr >= cfg.m_mapped_lo && addr <= cfg.m_mapped_hi)) begin
    count("unmapped_bytes_checked");
    return cfg.m_sub_agent_cfgs[sub].m_default_byte;
  end
  if (m_ref.exists(addr)) begin
    return m_ref[addr];
  end
  if (cfg.m_mapped_mem) begin
    count("mapped_default_bytes_checked");
    return mapped_mem_default(addr);
  end
  return cfg.m_sub_agent_cfgs[sub].m_default_byte;
endfunction : expected_byte

function void axi_agent_scoreboard::set_excl(int unsigned sub, axi_sub_txn rec);
  axi_sub_agent_cfg    sub_cfg = cfg.m_sub_agent_cfgs[sub];
  axi_txn_request_item req = rec.m_req;
  id_t                 id = id_t'(req.m_id);
  bit                  any_error = rec.m_policy.m_force_error;
  excl_mon_t           mon;
  addr_t               bytes;

  if (cfg.m_sub_is_lite || !sub_cfg.m_exclusive_support || !req.m_lock) begin
    return;
  end
  for (int unsigned n = 0; n <= int'(req.m_len); n++) begin
    any_error |= beat_in_err_region(sub_cfg, req.m_addr, req.m_size, req.m_len, req.m_burst, n);
  end
  if (any_error) begin
    if (m_excl.exists(sub)) begin
      m_excl[sub].delete(id);
    end
    return;
  end

  // Exclusive reads are size-aligned (H.c A7.2.4), so their bytes end without wrapping
  mon.req = req;
  bytes   = (addr_t'(req.m_len) + 1) << req.m_size;
  if (m_accepts.exists(sub)) begin
    foreach (m_accepts[sub][1][wid]) begin
      foreach (m_accepts[sub][1][wid][i]) begin
        axi_txn_request_item wr = m_accepts[sub][1][wid][i].m_req;
        addr_t               lo, hi;

        get_range(wr.m_addr, wr.m_size, wr.m_len, wr.m_burst, lo, hi);
        if (lo <= req.m_addr + bytes - 1 && req.m_addr <= hi) begin
          mon.unordered.push_back(m_accepts[sub][1][wid][i]);
        end
      end
    end
  end
  m_excl[sub][id] = mon;
endfunction : set_excl

function bit axi_agent_scoreboard::excl_matches(int unsigned sub, axi_mon_write_item item,
                                                output bit unordered);
  axi_txn_request_item rd;
  id_t                 id = item.m_awid;

  unordered = 1'b0;
  if (!(m_excl.exists(sub) && m_excl[sub].exists(id))) begin
    return 1'b0;
  end
  rd        = m_excl[sub][id].req;
  unordered = (m_excl[sub][id].unordered.size() > 0);
  return (rd.m_addr === item.m_awaddr && rd.m_region === item.m_awregion &&
          rd.m_len === item.m_awlen && rd.m_size === item.m_awsize &&
          rd.m_burst === item.m_awburst && rd.m_lock === item.m_awlock &&
          rd.m_cache === item.m_awcache && rd.m_prot === item.m_awprot);
endfunction : excl_matches

function void axi_agent_scoreboard::clear_excl(int unsigned sub, addr_t addr, axi_sub_txn rec);
  id_t ids[$];

  if (!m_excl.exists(sub)) begin
    return;
  end
  // Exclusive reads are size-aligned (H.c A7.2.4). Compare offsets from the read address to avoid
  // wrapping at the top of the address space.
  foreach (m_excl[sub][id]) begin
    axi_txn_request_item rd = m_excl[sub][id].req;
    addr_t               base = rd.m_addr;
    int unsigned         bytes = (int'(rd.m_len) + 1) << rd.m_size;
    axi_sub_txn          found[$] = m_excl[sub][id].unordered.find(t) with (t == rec);

    if (addr >= base && addr - base < bytes && found.size() == 0) begin
      ids.push_back(id);
    end
  end
  foreach (ids[i]) begin
    m_excl[sub].delete(ids[i]);
  end
endfunction : clear_excl

function void axi_agent_scoreboard::check_agent_write(int unsigned sub, axi_mon_write_item item,
                                                      axi_sub_txn rec);
  axi_sub_agent_cfg      sub_cfg = cfg.m_sub_agent_cfgs[sub];
  axi_sub_rsp_item       policy = rec.m_policy;
  int unsigned           bus_bytes = cfg.m_data_width / 8;
  bit                    lite = cfg.m_sub_is_lite;
  bit                    exclusive = !lite && sub_cfg.m_exclusive_support &&
                                     item.m_awlock === 1'b1;
  bit [AxiLenWidth-1:0]  len;
  bit [AxiSizeWidth-1:0] size;
  bit [AxiBurstWidth-1:0] burst;
  bit                    in_region = 1'b0;
  axi_resp_e             exp_resp;
  bit                    update;

  count("writes_checked");
  sub_burst(lite, item.m_awlen, item.m_awsize, item.m_awburst, len, size, burst);

  // Response priority: error region, policy error, rejected AXI4-Lite strobes, then exclusive-write
  // outcome
  for (int unsigned n = 0; n < item.m_wdata.size() && n <= len; n++) begin
    in_region |= beat_in_err_region(sub_cfg, item.m_awaddr, size, len, burst, n);
  end
  if (in_region) begin
    exp_resp = sub_cfg.m_err_resp;
  end else if (policy.m_force_error) begin
    exp_resp = policy.m_error_resp;
  end else if (lite && sub_cfg.m_lite_strb_policy == AxiLiteStrbErrorPartial &&
               item.m_wstrb[0] !== low_bits(bus_bytes)) begin
    exp_resp = RespSlverr;
  end else if (exclusive) begin
    bit unordered;

    exp_resp = excl_matches(sub, item, unordered) ? RespExOkay : RespOkay;
    // A write that was unordered against the read may have gone first and failed this one. That
    // write then invalidated the monitor, which stays invalid until the next exclusive read (H.c
    // A7.2.3).
    if (exp_resp == RespExOkay && unordered && item.m_bresp[1:0] === RespOkay) begin
      exp_resp = RespOkay;
      m_excl[sub].delete(id_t'(item.m_awid));
      count("exclusive_unordered");
    end
  end else begin
    exp_resp = RespOkay;
  end

  if (cfg.m_link.m_predict_responses && item.m_bresp[1:0] !== exp_resp) begin
    `uvm_error(get_full_name(),
               $sformatf({"%0s at subordinate end %0d was answered %0d, but its policy (%0s) asks ",
                          "for %0d."},
                         item.convert2string(), sub, item.m_bresp, policy.convert2string(),
                         exp_resp))
  end
  if ((item.m_buser & low_bits(cfg.m_sub_buser_width)) !==
      (policy.m_buser & low_bits(cfg.m_sub_buser_width))) begin
    `uvm_error(get_full_name(),
               $sformatf("%0s at subordinate end %0d has BUSER 0x%0h, but its policy has 0x%0h.",
                         item.convert2string(), sub, item.m_buser, policy.m_buser))
  end
  if (exclusive && exp_resp == RespOkay) begin
    count("exclusive_failures");
  end

  // OKAY or EXOKAY updates memory, except OKAY for a failed exclusive write
  update = (exp_resp == RespOkay && !exclusive) || exp_resp == RespExOkay;
  for (int unsigned n = 0; n < item.m_wdata.size() && update; n++) begin
    addr_t       beat_addr;
    int unsigned lower, upper;

    beat_lanes(item.m_awaddr, size, len, burst, bus_bytes, n, beat_addr, lower, upper);
    for (int unsigned lane = lower; lane <= upper; lane++) begin
      addr_t byte_addr = beat_addr - (beat_addr % bus_bytes) + lane;

      if (item.m_wstrb[n][lane] !== 1'b1 &&
          !(lite && sub_cfg.m_lite_strb_policy == AxiLiteStrbIgnore)) begin
        continue;
      end
      if (cfg.m_mapped_mem && !(byte_addr >= cfg.m_mapped_lo && byte_addr <= cfg.m_mapped_hi)) begin
        count("unmapped_bytes_written");
      end
      // A manager may drive any value on a lane that it does not strobe (H.c A3.4.4)
      if ($isunknown(item.m_wdata[n][8 * lane +: 8])) begin
        m_unknown[byte_addr] = 1'b1;
        count("unknown_bytes_written");
      end else begin
        m_ref[byte_addr] = item.m_wdata[n][8 * lane +: 8];
        if (m_unknown.exists(byte_addr)) begin
          m_unknown.delete(byte_addr);
        end
      end
      clear_excl(sub, byte_addr, rec);
    end
  end
endfunction : check_agent_write

function void axi_agent_scoreboard::check_agent_read(int unsigned sub, axi_mon_read_item item,
                                                     axi_sub_txn rec, bit predict);
  axi_sub_agent_cfg       sub_cfg = cfg.m_sub_agent_cfgs[sub];
  axi_sub_rsp_item        policy = rec.m_policy;
  int unsigned            bus_bytes = cfg.m_data_width / 8;
  bit                     lite = cfg.m_sub_is_lite;
  bit                     exclusive = !lite && sub_cfg.m_exclusive_support &&
                                      item.m_arlock === 1'b1;
  bit [AxiLenWidth-1:0]   len;
  bit [AxiSizeWidth-1:0]  size;
  bit [AxiBurstWidth-1:0] burst;
  axi_resp_e              exp_resp[$];
  bit                     any_error = 1'b0;

  count("reads_checked");
  sub_burst(lite, item.m_arlen, item.m_arsize, item.m_arburst, len, size, burst);

  // Each beat takes its region or policy error. Successful exclusive reads get EXOKAY on all beats
  // (H.c A7.2.5).
  for (int unsigned n = 0; n < item.m_rdata.size(); n++) begin
    if (beat_in_err_region(sub_cfg, item.m_araddr, size, len, burst, n)) begin
      exp_resp.push_back(sub_cfg.m_err_resp);
    end else if (policy.m_force_error) begin
      exp_resp.push_back(policy.m_error_resp);
    end else begin
      exp_resp.push_back(RespOkay);
    end
    any_error |= (exp_resp[n] != RespOkay);
  end
  if (exclusive && !any_error) begin
    foreach (exp_resp[n]) begin
      exp_resp[n] = RespExOkay;
    end
  end

  for (int unsigned n = 0; n < item.m_rdata.size(); n++) begin
    addr_t       beat_addr;
    int unsigned lower, upper;

    if (cfg.m_link.m_predict_responses && item.m_rresp[n][1:0] !== exp_resp[n]) begin
      `uvm_error(get_full_name(),
                 $sformatf({"R beat %0d of %0s at subordinate end %0d has RRESP %0d, but %0d ",
                            "was expected (policy %0s)."},
                           n, item.convert2string(), sub, item.m_rresp[n], exp_resp[n],
                           policy.convert2string()))
    end
    if ((item.m_ruser[n] & low_bits(cfg.m_sub_ruser_width)) !==
        (policy.m_ruser & low_bits(cfg.m_sub_ruser_width))) begin
      `uvm_error(get_full_name(),
                 $sformatf({"R beat %0d of %0s at subordinate end %0d has RUSER 0x%0h, but its ",
                            "policy has 0x%0h."},
                           n, item.convert2string(), sub, item.m_ruser[n], policy.m_ruser))
    end

    // Error responses leave data unspecified
    if (exp_resp[n][1]) begin
      continue;
    end
    beat_lanes(item.m_araddr, size, len, burst, bus_bytes, n, beat_addr, lower, upper);
    for (int unsigned lane = 0; lane < bus_bytes; lane++) begin
      addr_t      byte_addr = beat_addr - (beat_addr % bus_bytes) + lane;
      logic [7:0] value = item.m_rdata[n][8 * lane +: 8];
      bit [7:0]   exp_value;
      bit         known;

      if (lane < lower || lane > upper) begin
        if (sub_cfg.m_zero_inactive_lanes && value !== 8'h00) begin
          `uvm_error(get_full_name(),
                     $sformatf("R beat %0d of %0s has 0x%0h on inactive lane %0d, not zero.", n,
                               item.convert2string(), value, lane))
        end
        continue;
      end
      if (!predict) begin
        continue;
      end
      exp_value = expected_byte(sub, byte_addr, known);
      if (!known) begin
        continue;
      end
      count("read_bytes_checked");
      if (value !== exp_value) begin
        `uvm_error(get_full_name(),
                   $sformatf("R beat %0d of %0s has 0x%0h for byte 0x%0h, but 0x%0h was expected.",
                             n, item.convert2string(), value, byte_addr, exp_value))
      end
    end
  end
endfunction : check_agent_read

function bit axi_agent_scoreboard::model_addr_error(addr_t addr, bit [AxiSizeWidth-1:0] size,
                                                    bit [AxiLenWidth-1:0] len,
                                                    bit [AxiBurstWidth-1:0] burst,
                                                    int unsigned n, bit is_write,
                                                    logic [AxiMaxStrbWidth-1:0] strb,
                                                    output bit [AxiRespWidth-1:0] resp);
  int unsigned bus_bytes = cfg.m_data_width / 8;
  addr_t       beat_addr;
  int unsigned lower, upper;

  resp = RespOkay;
  beat_lanes(addr, size, len, burst, bus_bytes, n, beat_addr, lower, upper);
  for (int unsigned lane = lower; lane <= upper; lane++) begin
    addr_t byte_addr = beat_addr - (beat_addr % bus_bytes) + lane;

    if (is_write && strb[lane] !== 1'b1) begin
      continue;
    end
    foreach (cfg.m_link.m_model_err_ranges[i]) begin
      if (byte_addr >= cfg.m_link.m_model_err_ranges[i].lo &&
          byte_addr <= cfg.m_link.m_model_err_ranges[i].hi) begin
        resp = cfg.m_link.m_model_err_ranges[i].resp;
        return 1'b1;
      end
    end
  end
  return 1'b0;
endfunction : model_addr_error

function void axi_agent_scoreboard::check_model_write(axi_mon_write_item item);
  int unsigned           bus_bytes = cfg.m_data_width / 8;
  bit                    is_addr_err = 1'b0;
  bit [AxiRespWidth-1:0] addr_resp;
  bit [AxiRespWidth-1:0] exp_resp;
  logic [AxiRespWidth-1:0] resp = item.m_bresp;
  bit                    update;

  count("writes_checked");
  for (int unsigned n = 0; n < item.m_wdata.size() && !is_addr_err; n++) begin
    is_addr_err = model_addr_error(item.m_awaddr, item.m_awsize, item.m_awlen, item.m_awburst, n,
                                   1'b1, item.m_wstrb[n], addr_resp);
  end
  exp_resp = is_addr_err ? addr_resp : RespOkay;
  if (cfg.m_link.m_predict_responses && resp !== exp_resp) begin
    `uvm_error(get_full_name(), $sformatf("%0s was answered with BRESP %0d, but %0d was expected.",
                                          item.convert2string(), resp, exp_resp))
  end

  // OKAY writes update memory, while error writes follow the link's configured behavior
  update = (resp === RespOkay);
  if (!update && !(resp[1] === 1'b1 && cfg.m_link.m_error_writes_may_update)) begin
    return;
  end
  for (int unsigned n = 0; n < item.m_wdata.size(); n++) begin
    addr_t       beat_addr;
    int unsigned lower, upper;

    beat_lanes(item.m_awaddr, item.m_awsize, item.m_awlen, item.m_awburst, bus_bytes, n,
               beat_addr, lower, upper);
    for (int unsigned lane = lower; lane <= upper; lane++) begin
      addr_t byte_addr = beat_addr - (beat_addr % bus_bytes) + lane;

      if (item.m_wstrb[n][lane] !== 1'b1) begin
        continue;
      end
      if (update) begin
        m_ref[byte_addr] = item.m_wdata[n][8 * lane +: 8];
        if (m_unknown.exists(byte_addr)) begin
          m_unknown.delete(byte_addr);
        end
      end else begin
        m_unknown[byte_addr] = 1'b1;
      end
    end
  end
endfunction : check_model_write

function void axi_agent_scoreboard::check_model_read(axi_mon_read_item item, bit predict);
  int unsigned bus_bytes = cfg.m_data_width / 8;

  count("reads_checked");
  for (int unsigned n = 0; n < item.m_rdata.size(); n++) begin
    addr_t                 beat_addr;
    int unsigned           lower, upper;
    bit [AxiRespWidth-1:0] exp_resp;

    void'(model_addr_error(item.m_araddr, item.m_arsize, item.m_arlen, item.m_arburst, n, 1'b0,
                           '0, exp_resp));
    if (cfg.m_link.m_predict_responses && item.m_rresp[n] !== exp_resp) begin
      `uvm_error(get_full_name(),
                 $sformatf("R beat %0d of %0s has RRESP %0d, but %0d was expected.", n,
                           item.convert2string(), item.m_rresp[n], exp_resp))
    end

    // Error data is unspecified, and unwritten pulp_axi bytes are unknown
    if (item.m_rresp[n][1] !== 1'b0 || !predict) begin
      continue;
    end
    beat_lanes(item.m_araddr, item.m_arsize, item.m_arlen, item.m_arburst, bus_bytes, n,
               beat_addr, lower, upper);
    for (int unsigned lane = lower; lane <= upper; lane++) begin
      addr_t      byte_addr = beat_addr - (beat_addr % bus_bytes) + lane;
      logic [7:0] value = item.m_rdata[n][8 * lane +: 8];

      if (!m_ref.exists(byte_addr) || m_unknown.exists(byte_addr)) begin
        continue;
      end
      count("read_bytes_checked");
      if (value !== m_ref[byte_addr]) begin
        `uvm_error(get_full_name(),
                   $sformatf("R beat %0d of %0s has 0x%0h for byte 0x%0h, but 0x%0h was expected.",
                             n, item.convert2string(), value, byte_addr, m_ref[byte_addr]))
      end
    end
  end
endfunction : check_model_read

function void axi_agent_scoreboard::pair_link(int unsigned sub, bit dir, id_t id);
  while (m_link_mgr.exists(sub) && m_link_mgr[sub][dir].exists(id) &&
         m_link_mgr[sub][dir][id].size() > 0 &&
         m_link_sub.exists(sub) && m_link_sub[sub][dir].exists(id) &&
         m_link_sub[sub][dir][id].size() > 0) begin
    compare_link(m_link_mgr[sub][dir][id].pop_front(), m_link_mgr_idx[sub][dir][id].pop_front(),
                 m_link_sub[sub][dir][id].pop_front(), sub);
  end
endfunction : pair_link

function void axi_agent_scoreboard::compare_link(axi_mon_item mgr_item, int unsigned mgr,
                                                 axi_mon_item sub_item, int unsigned sub);
  int unsigned       bus_bytes = cfg.m_data_width / 8;
  string             what = $sformatf("%0s from manager end %0d at subordinate end %0d",
                                      mgr_item.convert2string(), mgr, sub);
  axi_mon_write_item mw, sw;
  axi_mon_read_item  mr, sr;

  if ($cast(mw, mgr_item)) begin
    if (!$cast(sw, sub_item)) begin
      `uvm_fatal(get_full_name(), "A write was paired with a read across the link.")
    end
    if (sw.m_awaddr !== mw.m_awaddr || sw.m_awlen !== mw.m_awlen ||
        sw.m_awsize !== mw.m_awsize || sw.m_awburst !== mw.m_awburst ||
        sw.m_awlock !== mw.m_awlock || sw.m_awcache !== mw.m_awcache ||
        sw.m_awprot !== mw.m_awprot || sw.m_awqos !== mw.m_awqos ||
        sw.m_awregion !== mw.m_awregion ||
        (sw.m_awuser & low_bits(cfg.m_awuser_width)) !==
        (mw.m_awuser & low_bits(cfg.m_awuser_width))) begin
      `uvm_error(get_full_name(), $sformatf("The subordinate end saw %0s for %0s.",
                                            sw.convert2string(), what))
    end
    if (sw.m_wdata.size() != mw.m_wdata.size()) begin
      `uvm_error(get_full_name(), $sformatf("The subordinate end saw %0d W beats for %0s.",
                                            sw.m_wdata.size(), what))
    end else begin
      foreach (mw.m_wdata[n]) begin
        bit differs = ((sw.m_wstrb[n] & low_bits(bus_bytes)) !==
                       (mw.m_wstrb[n] & low_bits(bus_bytes))) ||
                      ((sw.m_wuser[n] & low_bits(cfg.m_wuser_width)) !==
                       (mw.m_wuser[n] & low_bits(cfg.m_wuser_width)));

        for (int unsigned lane = 0; lane < bus_bytes; lane++) begin
          if (mw.m_wstrb[n][lane] === 1'b1) begin
            differs |= (sw.m_wdata[n][8 * lane +: 8] !== mw.m_wdata[n][8 * lane +: 8]);
          end
        end
        if (differs) begin
          `uvm_error(get_full_name(), $sformatf("W beat %0d of %0s differs across the link.", n,
                                                what))
        end
      end
    end
    if (mw.m_bresp !== sw.m_bresp ||
        (mw.m_buser & low_bits(cfg.m_buser_width)) !==
        (sw.m_buser & low_bits(cfg.m_buser_width))) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s got BRESP %0d BUSER 0x%0h, but the subordinate answered %0d 0x%0h.",
                           what, mw.m_bresp, mw.m_buser, sw.m_bresp, sw.m_buser))
    end
    count("link_writes_matched");
  end else begin
    if (!$cast(mr, mgr_item) || !$cast(sr, sub_item)) begin
      `uvm_fatal(get_full_name(), "A read was paired with a write across the link.")
    end
    if (sr.m_araddr !== mr.m_araddr || sr.m_arlen !== mr.m_arlen ||
        sr.m_arsize !== mr.m_arsize || sr.m_arburst !== mr.m_arburst ||
        sr.m_arlock !== mr.m_arlock || sr.m_arcache !== mr.m_arcache ||
        sr.m_arprot !== mr.m_arprot || sr.m_arqos !== mr.m_arqos ||
        sr.m_arregion !== mr.m_arregion ||
        (sr.m_aruser & low_bits(cfg.m_aruser_width)) !==
        (mr.m_aruser & low_bits(cfg.m_aruser_width))) begin
      `uvm_error(get_full_name(), $sformatf("The subordinate end saw %0s for %0s.",
                                            sr.convert2string(), what))
    end
    if (sr.m_rdata.size() != mr.m_rdata.size()) begin
      `uvm_error(get_full_name(), $sformatf("The subordinate end sent %0d R beats for %0s.",
                                            sr.m_rdata.size(), what))
    end else begin
      foreach (mr.m_rdata[n]) begin
        addr_t       beat_addr;
        int unsigned lower, upper;
        bit          differs = (mr.m_rresp[n] !== sr.m_rresp[n]) ||
                               ((mr.m_ruser[n] & low_bits(cfg.m_ruser_width)) !==
                                (sr.m_ruser[n] & low_bits(cfg.m_ruser_width)));

        beat_lanes(mr.m_araddr, mr.m_arsize, mr.m_arlen, mr.m_arburst, bus_bytes, n, beat_addr,
                   lower, upper);
        for (int unsigned lane = lower; lane <= upper && sr.m_rresp[n][1] === 1'b0; lane++) begin
          differs |= (mr.m_rdata[n][8 * lane +: 8] !== sr.m_rdata[n][8 * lane +: 8]);
        end
        if (differs) begin
          `uvm_error(get_full_name(), $sformatf("R beat %0d of %0s differs across the link.", n,
                                                what))
        end
      end
    end
    count("link_reads_matched");
  end
endfunction : compare_link

function void axi_agent_scoreboard::check_decode_error(int unsigned mgr, axi_mon_item item);
  axi_mon_write_item witem;
  axi_mon_read_item  ritem;

  // Unmapped crossbar accesses get DECERR, on every beat for reads (H.c A3.4.5)
  count("decode_errors");
  if ($cast(witem, item)) begin
    if (witem.m_bresp !== RespDecerr) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s from manager end %0d goes to no subordinate, but got BRESP %0d.",
                           item.convert2string(), mgr, witem.m_bresp))
    end
  end else if ($cast(ritem, item)) begin
    foreach (ritem.m_rresp[n]) begin
      if (ritem.m_rresp[n] !== RespDecerr) begin
        `uvm_error(get_full_name(),
                   $sformatf({"%0s from manager end %0d goes to no subordinate, but beat %0d got ",
                              "RRESP %0d."},
                             item.convert2string(), mgr, n, ritem.m_rresp[n]))
      end
    end
  end
endfunction : check_decode_error

function bit axi_agent_scoreboard::bridge_place(bit dir, axi_mon_item xfer, int unsigned num);
  // Sequences never overlap byte ranges of transfers in flight, so addresses identify bridge bursts
  // across reordered IDs (H.c A6.1). FIXED beats share an address and complete in beat order.
  foreach (m_bridge_bursts[dir][i]) begin
    axi_agent_bridge_burst burst = m_bridge_bursts[dir][i];

    foreach (burst.m_beat_addrs[n]) begin
      if (burst.m_transfers[n] == null && burst.m_beat_addrs[n] === xfer.get_addr()) begin
        burst.m_transfers[n]     = xfer;
        burst.m_transfer_nums[n] = num;
        return 1'b1;
      end
    end
  end
  return 1'b0;
endfunction : bridge_place

function void axi_agent_scoreboard::bridge_complete(bit dir, bit may_suppress = 1'b0,
                                                   bit at_end = 1'b0);
  int unsigned bus_bytes = cfg.m_data_width / 8;
  int          i = 0;

  while (i < m_bridge_bursts[dir].size()) begin
    axi_agent_bridge_burst burst = m_bridge_bursts[dir][i];
    bit                    suppressed;

    // A write with no strobes from an AXI4 burst may be suppressed (H.c B1.1.3)
    suppressed = may_suppress && dir && burst.m_txn != null &&
                 (at_end || burst.m_txn_time < $realtime) &&
                 burst.has_strobed_transfers(bus_bytes);
    if (burst.m_txn != null && (burst.has_all_transfers() || suppressed)) begin
      compare_bridge(burst);
      m_bridge_bursts[dir].delete(i);
    end else begin
      i++;
    end
  end
endfunction : bridge_complete

function void axi_agent_scoreboard::compare_bridge(axi_agent_bridge_burst burst);
  int unsigned       bus_bytes = cfg.m_data_width / 8;
  axi_mon_item       item = burst.m_txn;
  axi_mon_write_item mw, lw;
  axi_mon_read_item  mr, lr;
  axi_mon_item       xfers[$], extra[$];
  int unsigned       nums[$];

  burst.map_transfers(bus_bytes, xfers, nums, extra);
  foreach (extra[i]) begin
    `uvm_error(get_full_name(), $sformatf("%0s at the bridge belongs to no beat of %0s.",
                                          extra[i].convert2string(), item.convert2string()))
  end

  if ($cast(mw, item)) begin
    axi_resp_e   exp_bresp = RespOkay;
    int unsigned first_error_num;
    bit          any_error = 1'b0;
    bit          got_slverr = 1'b0;
    bit          got_decerr = 1'b0;
    string       resps;

    foreach (mw.m_wdata[n]) begin
      addr_t       beat_addr;
      int unsigned lower, upper;
      bit          zero_strobe;

      zero_strobe = burst.is_zero_strobe(n, bus_bytes);
      if (zero_strobe) begin
        count("bridge_zero_strobe_beats");
      end
      if (n < xfers.size() && xfers[n] == null && zero_strobe) begin
        // The bridge suppressed a write with no strobes (H.c B1.1.3)
        count("bridge_suppressed_beats");
        continue;
      end
      if (n >= xfers.size() || xfers[n] == null || !$cast(lw, xfers[n])) begin
        `uvm_error(get_full_name(), $sformatf("W beat %0d of %0s has no AXI4-Lite write.", n,
                                              item.convert2string()))
        continue;
      end

      // Each beat becomes an AXI4-Lite write at its beat address (H.c A3.4.2), preserving AxPROT,
      // strobes and data (B1.3.1)
      beat_lanes(mw.m_awaddr, mw.m_awsize, mw.m_awlen, mw.m_awburst, bus_bytes, n, beat_addr,
                 lower, upper);
      if (lw.m_awprot !== mw.m_awprot ||
          (lw.m_wstrb[0] & low_bits(bus_bytes)) !== (mw.m_wstrb[n] & low_bits(bus_bytes))) begin
        `uvm_error(get_full_name(),
                   $sformatf({"W beat %0d of %0s (beat address 0x%0h) became %0s with AWPROT %0d ",
                              "WSTRB 0x%0h."},
                             n, item.convert2string(), beat_addr, lw.convert2string(),
                             lw.m_awprot, lw.m_wstrb[0]))
      end
      for (int unsigned lane = 0; lane < bus_bytes; lane++) begin
        if (mw.m_wstrb[n][lane] === 1'b1 &&
            lw.m_wdata[0][8 * lane +: 8] !== mw.m_wdata[n][8 * lane +: 8]) begin
          `uvm_error(get_full_name(), $sformatf("W beat %0d of %0s changed on lane %0d.", n,
                                                item.convert2string(), lane))
        end
      end

      // Keep the first error
      resps = {resps, $sformatf(" %0d", lw.m_bresp)};
      if (lw.m_bresp[1] === 1'b1) begin
        got_slverr |= (lw.m_bresp[1:0] === RespSlverr);
        got_decerr |= (lw.m_bresp[1:0] === RespDecerr);
        if (!any_error || nums[n] < first_error_num) begin
          exp_bresp       = axi_resp_e'(lw.m_bresp[1:0]);
          first_error_num = nums[n];
        end
        any_error = 1'b1;
      end
    end

    // Combine AXI4-Lite write responses, retaining the first SLVERR or DECERR through the burst
    // (H.c B1.3.1)
    if (mw.m_bresp !== exp_bresp) begin
      `uvm_error(get_full_name(),
                 $sformatf({"%0s got BRESP %0d, but its AXI4-Lite writes were answered%0s, in ",
                            "beat order, so %0d was expected."},
                           item.convert2string(), mw.m_bresp, resps, exp_bresp))
    end
    count("bridge_writes_matched");
    if (any_error && mw.m_wdata.size() > 1) begin
      count("bridge_error_bursts");
    end
    if (got_slverr && got_decerr) begin
      count("bridge_mixed_error_bursts");
    end
    if (exp_bresp == RespDecerr && mw.m_wdata.size() > 1) begin
      count("bridge_decerr_bursts");
    end
  end else if ($cast(mr, item)) begin
    foreach (mr.m_rdata[n]) begin
      addr_t       beat_addr;
      int unsigned lower, upper;

      if (n >= xfers.size() || xfers[n] == null || !$cast(lr, xfers[n])) begin
        `uvm_error(get_full_name(), $sformatf("R beat %0d of %0s has no AXI4-Lite read.", n,
                                              item.convert2string()))
        continue;
      end

      // Each beat comes from an AXI4-Lite read of the address of the beat, with its response
      beat_lanes(mr.m_araddr, mr.m_arsize, mr.m_arlen, mr.m_arburst, bus_bytes, n, beat_addr,
                 lower, upper);
      if (lr.m_arprot !== mr.m_arprot || lr.m_rresp[0] !== mr.m_rresp[n]) begin
        `uvm_error(get_full_name(),
                   $sformatf({"R beat %0d of %0s (beat address 0x%0h, RRESP %0d) came from %0s ",
                              "with ARPROT %0d RRESP %0d."},
                             n, item.convert2string(), beat_addr, mr.m_rresp[n],
                             lr.convert2string(), lr.m_arprot, lr.m_rresp[0]))
      end
      for (int unsigned lane = lower; lane <= upper && mr.m_rresp[n][1] === 1'b0; lane++) begin
        if (lr.m_rdata[0][8 * lane +: 8] !== mr.m_rdata[n][8 * lane +: 8]) begin
          `uvm_error(get_full_name(), $sformatf("R beat %0d of %0s changed on lane %0d.", n,
                                                item.convert2string(), lane))
        end
      end
    end
    count("bridge_reads_matched");
  end
endfunction : compare_bridge

function void axi_agent_scoreboard::compare_mgr_driver_txns(int unsigned mgr, bit dir, id_t id);
  while (m_mon_txns.exists(mgr) && m_mon_txns[mgr][dir].exists(id) &&
         m_mon_txns[mgr][dir][id].size() > 0 &&
         m_drv_txns.exists(mgr) && m_drv_txns[mgr][dir].exists(id) &&
         m_drv_txns[mgr][dir][id].size() > 0) begin
    compare_txn(m_drv_txns[mgr][dir][id].pop_front(), m_mon_txns[mgr][dir][id].pop_front());
  end
endfunction : compare_mgr_driver_txns

function void axi_agent_scoreboard::compare_txn(axi_agent_mgr_txn txn, axi_mon_item item);
  int unsigned                  bus_bytes = cfg.m_data_width / 8;
  bit [AxiMaxRUserWidth-1:0]    ruser_mask = low_bits(cfg.m_ruser_width);
  axi_txn_request_item          req = txn.m_req;
  string                        what = txn.convert2string();
  axi_mon_write_item            witem;
  axi_mon_read_item             ritem;
  int unsigned                  num_beats;

  if (txn.m_is_write) begin
    if (!$cast(witem, item)) begin
      `uvm_fatal(get_full_name(), "A write record was paired with a monitored read.")
    end
    if (witem.m_awaddr !== req.m_addr || witem.m_awlen !== req.m_len ||
        witem.m_awsize !== req.m_size || witem.m_awburst !== req.m_burst ||
        witem.m_awlock !== req.m_lock || witem.m_awcache !== req.m_cache ||
        witem.m_awprot !== req.m_prot || witem.m_awqos !== req.m_qos ||
        witem.m_awregion !== req.m_region ||
        (witem.m_awuser & low_bits(cfg.m_awuser_width)) !== req.m_user) begin
      `uvm_error(get_full_name(), $sformatf("The manager sent %0s, but the bus carried %0s.", what,
                                            witem.convert2string()))
    end
    num_beats = witem.m_wdata.size();
    if (num_beats != txn.m_wdata.size()) begin
      `uvm_error(get_full_name(),
                 $sformatf("The manager sent %0d W beats for %0s, but the bus carried %0d.",
                           txn.m_wdata.size(), what, num_beats))
      num_beats = 0;
    end
    // Sequence data has the beat's addressed byte least significant
    for (int unsigned n = 0; n < num_beats; n++) begin
      addr_t       beat_addr;
      int unsigned lower, upper;

      beat_lanes(req.m_addr, req.m_size, req.m_len, req.m_burst, bus_bytes, n, beat_addr, lower,
                 upper);
      for (int unsigned lane = 0; lane < bus_bytes; lane++) begin
        bit       is_active = (lane >= lower && lane <= upper);
        bit       exp_strb = is_active && txn.m_wstrb[n][lane - lower];
        bit [7:0] exp_data = is_active ? txn.m_wdata[n][8 * (lane - lower) +: 8] : '0;

        if (witem.m_wstrb[n][lane] !== exp_strb ||
            (exp_strb && witem.m_wdata[n][8 * lane +: 8] !== exp_data)) begin
          `uvm_error(get_full_name(),
                     $sformatf("W beat %0d of %0s differs on lane %0d: strobe %0b data 0x%0h.", n,
                               what, lane, witem.m_wstrb[n][lane],
                               witem.m_wdata[n][8 * lane +: 8]))
        end
      end
      if ((witem.m_wuser[n] & low_bits(cfg.m_wuser_width)) !== txn.m_wuser[n]) begin
        `uvm_error(get_full_name(),
                   $sformatf("W beat %0d of %0s carried WUSER 0x%0h, but the manager sent 0x%0h.",
                             n, what, witem.m_wuser[n], txn.m_wuser[n]))
      end
    end
    if (txn.m_rsps.size() != 1 || witem.m_bresp !== txn.m_rsps[0].m_resp ||
        witem.m_bid !== txn.m_rsps[0].m_id ||
        (witem.m_buser & low_bits(cfg.m_buser_width)) !==
        (txn.m_rsps[0].m_user & low_bits(cfg.m_buser_width))) begin
      `uvm_error(get_full_name(),
                 $sformatf("The manager got a different B response for %0s than the bus, %0s.",
                           what, witem.convert2string()))
    end
    count("mgr_writes_matched");
  end else begin
    if (!$cast(ritem, item)) begin
      `uvm_fatal(get_full_name(), "A read record was paired with a monitored write.")
    end
    if (ritem.m_araddr !== req.m_addr || ritem.m_arlen !== req.m_len ||
        ritem.m_arsize !== req.m_size || ritem.m_arburst !== req.m_burst ||
        ritem.m_arlock !== req.m_lock || ritem.m_arcache !== req.m_cache ||
        ritem.m_arprot !== req.m_prot || ritem.m_arqos !== req.m_qos ||
        ritem.m_arregion !== req.m_region ||
        (ritem.m_aruser & low_bits(cfg.m_aruser_width)) !== req.m_user) begin
      `uvm_error(get_full_name(), $sformatf("The manager sent %0s, but the bus carried %0s.", what,
                                            ritem.convert2string()))
    end
    num_beats = ritem.m_rdata.size();
    if (num_beats != txn.m_rsps.size()) begin
      `uvm_error(get_full_name(),
                 $sformatf("The manager got %0d R beats for %0s, but the bus carried %0d.",
                           txn.m_rsps.size(), what, num_beats))
      num_beats = 0;
    end
    for (int unsigned n = 0; n < num_beats; n++) begin
      axi_txn_response_item rsp = txn.m_rsps[n];
      addr_t                beat_addr;
      int unsigned          lower, upper;

      beat_lanes(req.m_addr, req.m_size, req.m_len, req.m_burst, bus_bytes, n, beat_addr, lower,
                 upper);
      if (ritem.m_rresp[n] !== rsp.m_resp || rsp.m_id !== req.m_id ||
          rsp.m_last !== (n == num_beats - 1) ||
          (ritem.m_ruser[n] & ruser_mask) !== (rsp.m_user & ruser_mask)) begin
        `uvm_error(get_full_name(),
                   $sformatf({"R beat %0d of %0s: the manager got ID 0x%0h RRESP %0d RLAST %0b ",
                              "RUSER 0x%0h, but the bus carried RRESP %0d RUSER 0x%0h."},
                             n, what, rsp.m_id, rsp.m_resp, rsp.m_last, rsp.m_user,
                             ritem.m_rresp[n], ritem.m_ruser[n]))
      end
      // Error responses leave data unspecified (H.c A3.4.5)
      for (int unsigned lane = lower; lane <= upper && ritem.m_rresp[n][1] === 1'b0; lane++) begin
        if (ritem.m_rdata[n][8 * lane +: 8] !== rsp.m_rdata[8 * (lane - lower) +: 8]) begin
          `uvm_error(get_full_name(),
                     $sformatf({"R beat %0d of %0s: the manager got 0x%0h on lane %0d, but the ",
                                "bus carried 0x%0h."},
                               n, what, rsp.m_rdata[8 * (lane - lower) +: 8], lane,
                               ritem.m_rdata[n][8 * lane +: 8]))
        end
      end
    end
    count("mgr_reads_matched");
  end
endfunction : compare_txn

function void axi_agent_scoreboard::check_applied_policies();
  for (int unsigned sub = 0; sub < cfg.m_link.m_num_subs && cfg.m_link.m_sub_is_agent; sub++) begin
    axi_sub_rsp_item sent[$];
    int unsigned     num_applied = m_applied.exists(sub) ? m_applied[sub].size() : 0;

    if (cfg.m_rsp_seqs.exists(sub)) begin
      foreach (cfg.m_rsp_seqs[sub][s]) begin
        foreach (cfg.m_rsp_seqs[sub][s].m_sent_items[k]) begin
          sent.push_back(cfg.m_rsp_seqs[sub][s].m_sent_items[k]);
        end
      end
    end
    count("policies_applied", num_applied);

    // At most two policies are prefetched: one in the mailbox and one waiting for space
    if (num_applied > sent.size() || sent.size() - num_applied > 2) begin
      `uvm_error(get_full_name(),
                 $sformatf({"Subordinate end %0d gave %0d policy items from its sequences to ",
                            "transactions, but the sequences supplied %0d."},
                           sub, num_applied, sent.size()))
    end
    for (int unsigned k = 0; k < num_applied && k < sent.size(); k++) begin
      axi_sub_rsp_item applied = m_applied[sub][k];

      if (applied.m_latency != sent[k].m_latency ||
          applied.m_force_error != sent[k].m_force_error ||
          (applied.m_force_error && applied.m_error_resp != sent[k].m_error_resp) ||
          applied.m_buser != sent[k].m_buser || applied.m_ruser != sent[k].m_ruser) begin
        `uvm_error(get_full_name(),
                   $sformatf({"Subordinate end %0d gave policy item %0d as %0s, but its sequences ",
                              "supplied %0s."},
                             sub, k, applied.convert2string(), sent[k].convert2string()))
      end
    end
  end
endfunction : check_applied_policies

function void axi_agent_scoreboard::check_memory();
  for (int unsigned sub = 0; sub < cfg.m_link.m_num_subs; sub++) begin
    axi_mem_model_t mem = cfg.m_sub_agent_cfgs[sub].m_mem;

    // Every bus-written byte must match subordinate memory, except unmapped bytes whose writes are
    // dropped
    foreach (m_ref[addr]) begin
      if (m_unknown.exists(addr) || cfg.m_link.route(addr) != int'(sub)) begin
        continue;
      end
      if (cfg.m_mapped_mem && !(addr >= cfg.m_mapped_lo && addr <= cfg.m_mapped_hi)) begin
        if (mem.addr_exists(addr)) begin
          `uvm_error(get_full_name(),
                     $sformatf("Address 0x%0h is not mapped, but the memory holds 0x%0h there.",
                               addr, mem.system_memory[addr]))
        end
        continue;
      end
      count("memory_bytes_compared");
      if (!mem.addr_exists(addr)) begin
        `uvm_error(get_full_name(),
                   $sformatf({"The bus wrote 0x%0h to address 0x%0h, but the memory has no such ",
                              "byte."},
                             m_ref[addr], addr))
      end else if (mem.system_memory[addr] !== m_ref[addr]) begin
        `uvm_error(get_full_name(),
                   $sformatf("Address 0x%0h holds 0x%0h, but the bus wrote 0x%0h there.", addr,
                             mem.system_memory[addr], m_ref[addr]))
      end
    end

    // Memory must contain only bus-written bytes, at addresses that route to this subordinate
    foreach (mem.system_memory[addr]) begin
      int owner = cfg.m_link.route(addr);

      if (owner != int'(sub)) begin
        `uvm_error(get_full_name(),
                   $sformatf("Subordinate %0d holds 0x%0h at address 0x%0h, which routes to %0s.",
                             sub, mem.system_memory[addr], addr,
                             owner < 0 ? "no subordinate" : $sformatf("subordinate %0d", owner)))
      end else if (!m_ref.exists(addr) && !m_unknown.exists(addr)) begin
        `uvm_error(get_full_name(),
                   $sformatf("Address 0x%0h holds 0x%0h, but no write on the bus touched it.", addr,
                             mem.system_memory[addr]))
      end
    end
  end
endfunction : check_memory

function int unsigned axi_agent_scoreboard::get_count(string name);
  virtual axi_agent_probe_if probe = cfg.m_probe_vif;

  if (m_counts.exists(name)) begin
    return m_counts[name];
  end
  case (name)
    "aw_handshakes":          return probe.m_aw_handshakes;
    "w_handshakes":           return probe.m_w_handshakes;
    "b_handshakes":           return probe.m_b_handshakes;
    "ar_handshakes":          return probe.m_ar_handshakes;
    "r_handshakes":           return probe.m_r_handshakes;
    "aw_stalls":              return probe.m_aw_stalls;
    "w_stalls":               return probe.m_w_stalls;
    "b_stalls":               return probe.m_b_stalls;
    "ar_stalls":              return probe.m_ar_stalls;
    "r_stalls":               return probe.m_r_stalls;
    "aw_ready_first":         return probe.m_aw_ready_first;
    "w_ready_first":          return probe.m_w_ready_first;
    "b_ready_first":          return probe.m_b_ready_first;
    "ar_ready_first":         return probe.m_ar_ready_first;
    "r_ready_first":          return probe.m_r_ready_first;
    "aw_back_to_back":        return probe.m_aw_back_to_back;
    "w_back_to_back":         return probe.m_w_back_to_back;
    "b_back_to_back":         return probe.m_b_back_to_back;
    "ar_back_to_back":        return probe.m_ar_back_to_back;
    "r_back_to_back":         return probe.m_r_back_to_back;
    "fixed_bursts":           return probe.m_fixed_bursts;
    "incr_bursts":            return probe.m_incr_bursts;
    "wrap_bursts":            return probe.m_wrap_bursts;
    "narrow_bursts":          return probe.m_narrow_bursts;
    "unaligned_bursts":       return probe.m_unaligned_bursts;
    "bursts_to_4kb_boundary": return probe.m_bursts_to_4kb_boundary;
    "exclusive_requests":     return probe.m_exclusive_requests;
    "slverr_responses":       return probe.m_slverr_responses;
    "decerr_responses":       return probe.m_decerr_responses;
    "exokay_responses":       return probe.m_exokay_responses;
    "write_reorders":         return probe.m_write_reorders;
    "read_reorders":          return probe.m_read_reorders;
    "same_id_requests":       return probe.m_same_id_requests;
    "interleaved_r_beats":    return probe.m_interleaved_r_beats;
    "resets":                 return probe.m_resets;
    default: begin
      return 0;
    end
  endcase
endfunction : get_count

function void axi_agent_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);

  if (!cfg.en_scb) begin
    return;
  end

  foreach (m_mgr_txn_fifos[i]) begin
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(axi_mon_item, m_mgr_request_fifos[i])
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(axi_mon_item, m_mgr_txn_fifos[i])
  end
  foreach (m_sub_txn_fifos[i]) begin
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(axi_mon_item, m_sub_request_fifos[i])
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(axi_mon_item, m_sub_txn_fifos[i])
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(axi_sub_txn, m_sub_accept_fifos[i])
  end
  `DV_EOT_PRINT_TLM_FIFO_CONTENTS(axi_agent_mgr_txn, m_mgr_driver_txn_fifo)

  // Require all requests to complete with B or last R
  foreach (m_mgr_open[mgr]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_mgr_open[mgr][dir][id]) begin
        if (m_mgr_open[mgr][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"%0d requests with ID 0x%0h, starting with %0s, are still open at ",
                                "manager end %0d."},
                               m_mgr_open[mgr][dir][id].size(), id,
                               m_mgr_open[mgr][dir][id][0].convert2string(), mgr))
        end
      end
    end
  end
  foreach (m_sub_open[sub]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_sub_open[sub][dir][id]) begin
        if (m_sub_open[sub][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"%0d requests with ID 0x%0h, starting with %0s, are still open at ",
                                "subordinate end %0d."},
                               m_sub_open[sub][dir][id].size(), id,
                               m_sub_open[sub][dir][id][0].convert2string(), sub))
        end
      end
    end
  end
  check_w_matched();

  // Require all records, link transactions and acceptances to be paired
  foreach (m_mon_txns[mgr]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_mon_txns[mgr][dir][id]) begin
        if (m_mon_txns[mgr][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"%0d transactions with ID 0x%0h at manager end %0d, starting with ",
                                "%0s, have no record."},
                               m_mon_txns[mgr][dir][id].size(), id, mgr,
                               m_mon_txns[mgr][dir][id][0].convert2string()))
        end
      end
    end
  end
  foreach (m_drv_txns[mgr]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_drv_txns[mgr][dir][id]) begin
        if (m_drv_txns[mgr][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"%0d records with ID 0x%0h from manager end %0d, starting with ",
                                "%0s, never matched the bus."},
                               m_drv_txns[mgr][dir][id].size(), id, mgr,
                               m_drv_txns[mgr][dir][id][0].convert2string()))
        end
      end
    end
  end
  foreach (m_link_mgr[sub]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_link_mgr[sub][dir][id]) begin
        if (m_link_mgr[sub][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"%0d manager-end transactions for ID 0x%0h at subordinate end ",
                                "%0d, starting with %0s, never reached it."},
                               m_link_mgr[sub][dir][id].size(), id, sub,
                               m_link_mgr[sub][dir][id][0].convert2string()))
        end
      end
    end
  end
  foreach (m_link_sub[sub]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_link_sub[sub][dir][id]) begin
        if (m_link_sub[sub][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"%0d transactions with ID 0x%0h at subordinate end %0d, starting ",
                                "with %0s, came from no manager end."},
                               m_link_sub[sub][dir][id].size(), id, sub,
                               m_link_sub[sub][dir][id][0].convert2string()))
        end
      end
    end
  end
  bridge_complete(1'b1, 1'b1, 1'b1);
  for (int dir = 0; dir < 2; dir++) begin
    foreach (m_bridge_bursts[dir][i]) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s at the bridge %0s.", m_bridge_bursts[dir][i].m_req.convert2string(),
                           m_bridge_bursts[dir][i].m_txn == null ?
                           "never completed at the manager end" :
                           "is missing AXI4-Lite transfers"))
    end
    foreach (m_bridge_spares[dir][i]) begin
      `uvm_error(get_full_name(), $sformatf("%0s at the bridge came from no burst.",
                                            m_bridge_spares[dir][i].convert2string()))
    end
  end
  foreach (m_accepts[sub]) begin
    for (int dir = 0; dir < 2; dir++) begin
      foreach (m_accepts[sub][dir][id]) begin
        if (m_accepts[sub][dir][id].size() > 0) begin
          `uvm_error(get_full_name(),
                     $sformatf({"Subordinate end %0d accepted %0d transactions with ID 0x%0h, ",
                                "starting with %0s, that never completed."},
                               sub, m_accepts[sub][dir][id].size(), id,
                               m_accepts[sub][dir][id][0].convert2string()))
        end
      end
    end
  end

  check_applied_policies();

  // Reject empty traffic runs that would pass without exercising checks
  if (get_count("writes_checked") == 0 || get_count("reads_checked") == 0) begin
    `uvm_error(get_full_name(),
               $sformatf({"The scoreboard saw %0d writes and %0d reads. A self-test that does ",
                          "not do both has checked nothing."},
                         get_count("writes_checked"), get_count("reads_checked")))
  end

  if (cfg.en_scb_mem_chk && cfg.m_link.m_sub_is_agent) begin
    check_memory();
  end

  // Check required activity
  foreach (cfg.m_min_counts[name]) begin
    if (get_count(name) < cfg.m_min_counts[name]) begin
      `uvm_error(get_full_name(), $sformatf("%0s is %0d, but the test needs at least %0d.", name,
                                            get_count(name), cfg.m_min_counts[name]))
    end
  end
endfunction : check_phase

function void axi_agent_scoreboard::check_w_matched();
  // W may come before its AW, but each W burst belongs to a write transaction (H.c A3.3). Reset
  // drops both, so the probes count from the last reset.
  foreach (cfg.m_bus_probe_vifs[i]) begin
    virtual axi_agent_probe_if probe = cfg.m_bus_probe_vifs[i];

    if (probe.m_w_bursts_since_reset != probe.m_aws_since_reset) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s saw %0d AW requests and %0d W bursts since the last reset.",
                           probe.m_path, probe.m_aws_since_reset, probe.m_w_bursts_since_reset))
    end
    if (probe.m_w_beats_open != 0) begin
      `uvm_error(get_full_name(),
                 $sformatf("%0s ended with %0d W beats of a burst with no WLAST.", probe.m_path,
                           probe.m_w_beats_open))
    end
  end
endfunction : check_w_matched

function void axi_agent_scoreboard::report_phase(uvm_phase phase);
  super.report_phase(phase);

  foreach (cfg.m_min_counts[name]) begin
    `uvm_info(get_full_name(), $sformatf("%0s is %0d (at least %0d)", name, get_count(name),
                                         cfg.m_min_counts[name]), UVM_LOW)
  end
  foreach (m_counts[name]) begin
    `uvm_info(get_full_name(), $sformatf("%0s is %0d", name, m_counts[name]), UVM_LOW)
  end
  `uvm_info(get_full_name(),
            $sformatf("Link %0s, data width %0d, ID width %0d, AXI4-Lite %0b, X when idle %0b",
                      cfg.m_link.m_name, cfg.m_data_width, cfg.m_id_width, cfg.m_is_lite,
                      cfg.m_drive_x_when_idle), UVM_LOW)
endfunction : report_phase
