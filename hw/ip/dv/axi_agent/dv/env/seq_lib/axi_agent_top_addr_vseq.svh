// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test the top of the address space with +axi_addr_width=64. First send transfer sequences
// randomized using only bus properties. Then write WRAP bursts of several shapes in the final wrap
// regions (AMBA AXI H.c A3.4.1), read each beat separately at its computed address, and read each
// whole burst. Compute addresses one bit wider than the bus, independently of agent and scoreboard
// helpers. Finally, reset during a write to the last eight bytes, then rewrite and read them.

class axi_agent_top_addr_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_top_addr_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Return a request with this address and burst, its other attributes random
  extern protected function axi_agent_rand_req top_req(addr_t addr, int unsigned len,
                                                       int unsigned size, burst_e burst);

  // Send when ready, require OKAY responses, and return the sequence
  extern protected task send_okay(input axi_agent_rand_req req, input bit is_write,
                                  output axi_transfer_seq seq);

  // Check that read beat n_rd of rd returned the data that write beat n_wr of wr carried
  extern protected function void check_beat(axi_transfer_seq wr, int unsigned n_wr,
                                            axi_transfer_seq rd, int unsigned n_rd,
                                            addr_t beat_addr);

  // Write a WRAP burst, read each beat separately at its address, then read the whole WRAP burst
  extern protected task wrap_round_trip(addr_t addr, int unsigned len, int unsigned size);

  // Write the last eight bytes and reset while the subordinate delays B
  extern protected task reset_top_write();
endclass : axi_agent_top_addr_vseq


function axi_agent_top_addr_vseq::new(string name = "");
  super.new(name);
  // Write all bytes so readback has known values
  m_partial_strb_pct = 0;
endfunction : new

function axi_agent_rand_req axi_agent_top_addr_vseq::top_req(addr_t addr, int unsigned len,
                                                             int unsigned size, burst_e burst);
  axi_agent_rand_req req = new_req();

  req.m_addr  = addr;
  req.m_len   = len;
  req.m_size  = size;
  req.m_burst = burst;
  req.m_lock  = 1'b0;
  return req;
endfunction : top_req

task axi_agent_top_addr_vseq::send_okay(input axi_agent_rand_req req, input bit is_write,
                                        output axi_transfer_seq seq);
  wait_ready();
  send(req, is_write, seq);
  foreach (seq.m_responses[n]) begin
    if (seq.m_responses[n].m_resp != RespOkay) begin
      `uvm_error(get_full_name(), $sformatf("Response %0d to the %0s at 0x%0h was %0d, not OKAY.",
                                            n, is_write ? "write" : "read", req.m_addr,
                                            seq.m_responses[n].m_resp))
    end
  end
endtask : send_okay

function void axi_agent_top_addr_vseq::check_beat(axi_transfer_seq wr, int unsigned n_wr,
                                                  axi_transfer_seq rd, int unsigned n_rd,
                                                  addr_t beat_addr);
  int unsigned nbytes = 1 << wr.m_req.m_size;

  if (n_rd >= rd.m_responses.size()) begin
    `uvm_error(get_full_name(), $sformatf("The read at 0x%0h returned %0d beats, not %0d.",
                                          rd.m_req.m_addr, rd.m_responses.size(), n_rd + 1))
    return;
  end
  for (int unsigned k = 0; k < nbytes; k++) begin
    bit [7:0] written = wr.m_beat_wdata[n_wr][8 * k +: 8];
    bit [7:0] read = rd.m_responses[n_rd].m_rdata[8 * k +: 8];

    if (wr.m_beat_wstrb[n_wr][k] && read !== written) begin
      `uvm_error(get_full_name(),
                 $sformatf({"Byte 0x%0h, of beat %0d of the write to 0x%0h, read back as 0x%0h, ",
                            "not 0x%0h."},
                           beat_addr + k, n_wr, wr.m_req.m_addr, read, written))
    end
  end
endfunction : check_beat

task axi_agent_top_addr_vseq::wrap_round_trip(addr_t addr, int unsigned len, int unsigned size);
  int unsigned            nbytes = 1 << size;
  int unsigned            total = nbytes * (len + 1);
  bit [AxiMaxAddrWidth:0] boundary = (addr / total) * total;
  addr_t                  beat_addrs[$];
  axi_transfer_seq        wr, rd;

  send_okay(top_req(addr, len, size, BurstWrap), 1'b1, wr);
  for (int unsigned n = 0; n <= len; n++) begin
    // Compute Address_N modulo the wrap region (H.c A3.4.1). WRAP starts aligned, so no address
    // alignment is needed.
    bit [AxiMaxAddrWidth:0] beat_addr = addr + n * nbytes;

    if (beat_addr >= boundary + total) begin
      beat_addr -= total;
    end
    beat_addrs.push_back(addr_t'(beat_addr));
    send_okay(top_req(beat_addrs[n], 0, size, BurstIncr), 1'b0, rd);
    check_beat(wr, n, rd, 0, beat_addrs[n]);
  end

  send_okay(top_req(addr, len, size, BurstWrap), 1'b0, rd);
  foreach (beat_addrs[n]) begin
    check_beat(wr, n, rd, n, beat_addrs[n]);
  end
endtask : wrap_round_trip

task axi_agent_top_addr_vseq::reset_top_write();
  addr_t           top = 64'hffff_ffff_ffff_fff8;
  axi_transfer_seq seq;

  // Use one policy to delay B until after reset
  m_latency_min = 200;
  m_latency_max = 200;
  run_rsp_seq_nonblocking(1);
  m_latency_min = 0;
  m_latency_max = 0;

  wait_ready();
  fork
    send(top_req(top, 0, 3, BurstIncr), 1'b1, seq);
    begin
      for (int unsigned waited = 0; cfg.m_probe_vif.m_writes_open.size() == 0; waited++) begin
        if (waited == 1000) begin
          `uvm_fatal(get_full_name(), "The write to the top of the address space never started.")
        end
        cfg.clk_rst_vif.wait_clks(1);
      end
      cfg.clk_rst_vif.wait_clks(5);
      if (cfg.m_probe_vif.m_writes_open.size() == 0) begin
        `uvm_fatal(get_full_name(), "The write to the top of the address space ended too soon.")
      end
      `uvm_info(get_full_name(), "Resetting the bus while the write to the top is open", UVM_LOW)
      cfg.clk_rst_vif.apply_reset(.reset_width_clks(10));
    end
  join
endtask : reset_top_write

task axi_agent_top_addr_vseq::body();
  axi_transfer_seq wr, rd;

  if (cfg.m_addr_width != 64) begin
    `uvm_fatal(get_full_name(), $sformatf("This test needs a 64 bit address bus, not %0d bits.",
                                          cfg.m_addr_width))
  end
  need("wrap_bursts", 10);
  need("writes_cut_by_reset", 1);
  need("read_bytes_checked", 200);
  need("memory_bytes_compared", 128);

  send_bus_seqs(30);

  // A full-width burst over the last 32 bytes, from 8 bytes below its end
  wrap_round_trip(64'hffff_ffff_ffff_ffe8, 3, 3);
  // Narrow bursts, one within a region smaller than the data bus
  wrap_round_trip(64'hffff_ffff_ffff_fffd, 3, 0);
  wrap_round_trip(64'hffff_ffff_ffff_fff4, 7, 2);
  wrap_round_trip(64'hffff_ffff_ffff_fffe, 1, 0);
  // The longest WRAP burst, over the last 128 bytes
  wrap_round_trip(64'hffff_ffff_ffff_ffd0, 15, 3);

  reset_top_write();

  // Rewrite and read the bytes left unknown by reset
  send_okay(top_req(64'hffff_ffff_ffff_fff8, 0, 3, BurstIncr), 1'b1, wr);
  send_okay(top_req(64'hffff_ffff_ffff_fff8, 0, 3, BurstIncr), 1'b0, rd);
  check_beat(wr, 0, rd, 0, 64'hffff_ffff_ffff_fff8);
endtask : body
