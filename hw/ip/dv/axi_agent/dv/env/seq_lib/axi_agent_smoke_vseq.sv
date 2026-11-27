// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test configuration-only responses with INCR, WRAP and FIXED bursts, narrow and unaligned
// transfers, INCR bursts ending at 4KB boundaries, and 17- and 256-beat INCR bursts. First
// randomize transfer sequences using only bus properties, then restart selected sequences three
// times.

class axi_agent_smoke_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_smoke_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Write and read back 17- and 256-beat INCR bursts (AMBA AXI H.c A3.4.1), using the widest
  // transfers that fit within one window page
  extern protected task long_bursts();

  // Start a single write, generated INCR write and checking reads three times each. Change
  // single-write data after the first start and clear only burst data on the third. Require fresh
  // data and results belonging only to each start.
  extern protected task reused_seqs();

  // Check zero-based start completed with one request and all responses, each OKAY
  extern protected function void check_reused(axi_transfer_seq seq, int unsigned start);

  // Check rd against strobed wdata bytes per beat, with the addressed byte least significant
  extern protected function void check_read_back(axi_transfer_seq          rd,
                                                 bit [AxiMaxDataWidth-1:0] wdata[$],
                                                 bit [AxiMaxStrbWidth-1:0] wstrb[$],
                                                 string                    what);
endclass : axi_agent_smoke_vseq


function axi_agent_smoke_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_smoke_vseq::long_bursts();
  int unsigned lens[2] = '{16, 255};
  addr_t       num_pages = (cfg.m_link.m_addr_hi - cfg.m_link.m_addr_lo + 1) / 4096;

  foreach (lens[i]) begin
    axi_agent_rand_req req = new_req();
    int unsigned       size = $clog2(cfg.m_data_width / 8);
    int unsigned       bytes;
    axi_transfer_seq   wr, rd;

    while (((lens[i] + 1) << size) > 4096) begin
      size--;
    end
    bytes = (lens[i] + 1) << size;

    req.m_addr  = cfg.m_link.m_addr_lo + 4096 * $urandom_range(0, num_pages - 1) +
                  ($urandom_range(0, (4096 - bytes) >> size) << size);
    req.m_len   = lens[i];
    req.m_size  = size;
    req.m_burst = BurstIncr;
    req.m_lock  = 1'b0;
    wait_ready();
    send(req, 1'b1, wr);
    wait_ready();
    send(req, 1'b0, rd);
  end
endtask : long_bursts

task axi_agent_smoke_vseq::reused_seqs();
  axi_vif_t                 vif = p_sequencer.m_mgr_agents[0].get_vif();
  axi_single_write_seq      wr_seq = axi_single_write_seq::type_id::create("reused_wr_seq");
  axi_single_read_seq       rd_seq = axi_single_read_seq::type_id::create("reused_rd_seq");
  axi_transfer_seq          burst_seq = axi_transfer_seq::type_id::create("reused_burst_seq");
  axi_transfer_seq          check_seq = axi_transfer_seq::type_id::create("reused_check_seq");
  addr_t                    addr;
  bit [AxiSizeWidth-1:0]    size;
  bit [AxiMaxDataWidth-1:0] first_wdata;
  bit [AxiMaxDataWidth-1:0] first_beats[$];

  wr_seq.set_bus_properties(vif);
  rd_seq.set_bus_properties(vif);
  burst_seq.set_bus_properties(vif);
  check_seq.set_bus_properties(vif);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(burst_seq,
                                 m_write == 1'b1;
                                 m_req.m_lock  == 1'b0;
                                 m_req.m_burst == BurstIncr;
                                 m_req.m_size  == m_max_size;
                                 m_is_lite || m_req.m_len inside {[3:7]};)

  for (int unsigned i = 0; i < 3; i++) begin
    // Rewrite the same bytes with fresh data after the first start
    if (i == 0) begin
      `DV_CHECK_RANDOMIZE_WITH_FATAL(wr_seq, m_req.m_lock == 1'b0;)
    end else begin
      `DV_CHECK_RANDOMIZE_WITH_FATAL(wr_seq,
                                     m_req.m_lock  == 1'b0;
                                     m_req.m_addr  == local::addr;
                                     m_req.m_size  == local::size;
                                     m_wdata != local::first_wdata;)
    end
    addr        = wr_seq.m_req.m_addr;
    size        = wr_seq.m_req.m_size;
    first_wdata = wr_seq.m_wdata;
    wait_ready();
    wr_seq.start(p_sequencer.m_mgr_sequencers[0]);
    record(wr_seq, 0);
    check_reused(wr_seq, i);

    `DV_CHECK_RANDOMIZE_WITH_FATAL(rd_seq,
                                   m_req.m_lock == 1'b0;
                                   m_req.m_addr == local::addr;
                                   m_req.m_size == local::size;)
    wait_ready();
    rd_seq.start(p_sequencer.m_mgr_sequencers[0]);
    record(rd_seq, 0);
    check_reused(rd_seq, i);
    check_read_back(rd_seq, '{wr_seq.m_wdata}, '{wr_seq.m_wstrb},
                    $sformatf("Start %0d of a reused single write", i + 1));

    // Reuse the randomized burst with fresh data. Clearing only m_beat_wdata on the third start
    // must also regenerate strobes and WUSER.
    if (i == 2) begin
      burst_seq.m_beat_wdata.delete();
    end
    wait_ready();
    burst_seq.start(p_sequencer.m_mgr_sequencers[0]);
    record(burst_seq, 0);
    check_reused(burst_seq, i);
    if (burst_seq.m_beat_wdata.size() != int'(burst_seq.m_req.m_len) + 1 ||
        burst_seq.m_beat_wstrb.size() != int'(burst_seq.m_req.m_len) + 1 ||
        burst_seq.m_beat_wuser.size() != int'(burst_seq.m_req.m_len) + 1) begin
      `uvm_error(get_full_name(),
                 $sformatf({"Start %0d of the write burst at 0x%0h, AxLEN %0d, left %0d data, %0d ",
                            "strobe and %0d WUSER entries."},
                           i + 1, burst_seq.m_req.m_addr, burst_seq.m_req.m_len,
                           burst_seq.m_beat_wdata.size(), burst_seq.m_beat_wstrb.size(),
                           burst_seq.m_beat_wuser.size()))
    end
    if (i > 0) begin
      bit same = (burst_seq.m_beat_wdata.size() == first_beats.size());

      foreach (first_beats[n]) begin
        same &= (n < burst_seq.m_beat_wdata.size() && burst_seq.m_beat_wdata[n] == first_beats[n]);
      end
      if (same) begin
        `uvm_error(get_full_name(),
                   $sformatf("Restarting the write burst at 0x%0h resent its first data.",
                             burst_seq.m_req.m_addr))
      end
    end
    first_beats = burst_seq.m_beat_wdata;

    `DV_CHECK_RANDOMIZE_WITH_FATAL(check_seq,
                                   m_write == 1'b0;
                                   m_req.m_lock  == 1'b0;
                                   m_req.m_addr  == local::burst_seq.m_req.m_addr;
                                   m_req.m_len   == local::burst_seq.m_req.m_len;
                                   m_req.m_size  == local::burst_seq.m_req.m_size;
                                   m_req.m_burst == BurstIncr;)
    wait_ready();
    check_seq.start(p_sequencer.m_mgr_sequencers[0]);
    record(check_seq, 0);
    check_reused(check_seq, i);
    check_read_back(check_seq, burst_seq.m_beat_wdata, burst_seq.m_beat_wstrb,
                    $sformatf("Start %0d of a reused write burst", i + 1));
  end
endtask : reused_seqs

function void axi_agent_smoke_vseq::check_reused(axi_transfer_seq seq, int unsigned start);
  int unsigned num_rsps = seq.m_write ? 1 : int'(seq.m_req.m_len) + 1;

  if (seq.m_requests.size() != 1 || seq.m_responses.size() != num_rsps ||
      !seq.has_full_transaction()) begin
    `uvm_error(get_full_name(),
               $sformatf({"Start %0d of a reused %0s ended with %0d requests and %0d responses, ",
                          "not 1 and %0d, and has_full_transaction() %0b."},
                         start + 1, seq.get_type_name(), seq.m_requests.size(),
                         seq.m_responses.size(), num_rsps, seq.has_full_transaction()))
  end
  foreach (seq.m_responses[n]) begin
    if (seq.m_responses[n].m_resp != RespOkay) begin
      `uvm_error(get_full_name(),
                 $sformatf("Start %0d of a reused %0s got response %0d to beat %0d, not OKAY.",
                           start + 1, seq.get_type_name(), seq.m_responses[n].m_resp, n))
    end
  end
endfunction : check_reused

function void axi_agent_smoke_vseq::check_read_back(axi_transfer_seq          rd,
                                                    bit [AxiMaxDataWidth-1:0] wdata[$],
                                                    bit [AxiMaxStrbWidth-1:0] wstrb[$],
                                                    string                    what);
  foreach (wdata[n]) begin
    for (int unsigned b = 0; b < AxiMaxStrbWidth; b++) begin
      if (wstrb[n][b] && n < rd.m_responses.size() &&
          rd.m_responses[n].m_rdata[8 * b +: 8] != wdata[n][8 * b +: 8]) begin
        `uvm_error(get_full_name(),
                   $sformatf("%0s: byte %0d of beat %0d at 0x%0h read back as 0x%0h, not 0x%0h.",
                             what, b, n, rd.m_req.m_addr, rd.m_responses[n].m_rdata[8 * b +: 8],
                             wdata[n][8 * b +: 8]))
        return;
      end
    end
  end
endfunction : check_read_back

task axi_agent_smoke_vseq::body();
  need("fixed_bursts", 5);
  need("incr_bursts", 20);
  need("wrap_bursts", 5);
  need("narrow_bursts", 10);
  need("unaligned_bursts", 5);
  need("bursts_to_4kb_boundary", 2);
  need("long_writes", 2);
  need("long_reads", 2);
  need("max_len_writes", 1);
  need("max_len_reads", 1);
  need("read_bytes_checked", 200);
  need("memory_bytes_compared", 200);
  need("mgr_writes_matched", 20);
  need("mgr_reads_matched", 20);

  send_bus_seqs(30);
  reused_seqs();
  long_bursts();
  super.body();
endtask : body
