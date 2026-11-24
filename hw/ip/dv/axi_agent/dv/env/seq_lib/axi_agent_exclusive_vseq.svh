// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Test exclusive accesses serially (AMBA AXI H.c A7.2), including the top of a 64-bit address
// space. With exclusive support, a matching read/write succeeds. Intervening writes, also one made
// while the read waits for its data, a missing read, mismatched AxADDR, AxLEN, AxSIZE, AxBURST,
// AxCACHE or AxPROT (A7.2.4), or a later same-ID exclusive read to other bytes, even one with an
// error (A7.2.1), makes the write fail without changing memory. So does a write whose data arrives
// after the read is accepted, for every later matching write (A6.1, A7.2.3). AxREGION cannot differ
// at one address (A8.2.1). Without support, accesses get OKAY and writes update memory. Check
// responses here and independently in the scoreboard.

class axi_agent_exclusive_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_exclusive_vseq)

  int unsigned m_num_rounds = 10;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Return a random exclusive request, which obeys the restrictions of H.c A7.2.4
  extern protected function axi_agent_rand_req new_excl_req();

  extern protected function axi_agent_rand_req copy_req(axi_agent_rand_req req);

  // Read exclusively, attempt a mismatched write that fails, then a matching write that succeeds.
  // Vary the A7.2.4 attributes except AxREGION.
  extern protected task mismatched_write(int unsigned which);

  // Read exclusively, read neighboring bytes exclusively with the same ID (inject an error if
  // with_error), then check the first read's matching write fails and read back its bytes
  extern protected task moved_monitor(bit with_error);

  // Read the last eight bytes exclusively, overwrite normally, then check the exclusive write fails
  extern protected task top_of_address_space();

  // Hold exclusive read data while another ID writes the same bytes. After completing the read,
  // require the matching exclusive write to fail.
  extern protected task write_during_read();

  // Hold normal write data until an exclusive read of the same bytes is accepted, leaving them
  // unordered (A6.1). Both matching exclusive writes must fail without changing memory.
  extern protected task unordered_write();
endclass : axi_agent_exclusive_vseq


function axi_agent_exclusive_vseq::new(string name = "");
  super.new(name);
  // Set strobes so the intervening write invalidates the exclusive monitor
  m_partial_strb_pct = 0;
endfunction : new

function axi_agent_rand_req axi_agent_exclusive_vseq::new_excl_req();
  axi_agent_rand_req req = axi_agent_rand_req::type_id::create("req");

  req.set_bus(cfg);
  req.m_allow_lock = 1'b1;
  `DV_CHECK_RANDOMIZE_WITH_FATAL(req, m_lock == 1'b1;)
  return req;
endfunction : new_excl_req

function axi_agent_rand_req axi_agent_exclusive_vseq::copy_req(axi_agent_rand_req req);
  axi_agent_rand_req copy = axi_agent_rand_req::type_id::create("copy");

  copy.copy(req);
  return copy;
endfunction : copy_req

task axi_agent_exclusive_vseq::mismatched_write(int unsigned which);
  axi_agent_rand_req rd;
  axi_agent_rand_req wr;
  string             what;
  int unsigned       bus_size = $clog2(cfg.m_data_width / 8);

  // Vary an eight-byte access between two four-byte beats and one eight-byte beat on 64-bit buses,
  // and vary the address on narrower buses
  if (which == 0 && bus_size < 3) begin
    which = 1;
  end

  rd = new_excl_req();
  case (which)
    0: begin
      what = "AxLEN and AxSIZE";
      rd.m_len   = 1;
      rd.m_size  = 2;
      rd.m_burst = BurstIncr;
      rd.m_addr  = rd.m_addr & ~64'h7;
      wr = copy_req(rd);
      wr.m_len  = 0;
      wr.m_size = 3;
    end
    1: begin
      what = "AxADDR";
      wr = copy_req(rd);
      wr.m_addr = rd.m_addr ^ ((int'(rd.m_len) + 1) << rd.m_size);
    end
    2: begin
      what = "AxBURST";
      rd.m_len   = 1;
      rd.m_size  = 0;
      rd.m_burst = BurstIncr;
      rd.m_addr  = rd.m_addr & ~64'h1;
      wr = copy_req(rd);
      wr.m_burst = BurstWrap;
    end
    3: begin
      what = "AxCACHE";
      wr = copy_req(rd);
      wr.m_cache = (rd.m_cache == 4'b0010) ? 4'b0011 : 4'b0010;
    end
    default: begin
      what = "AxPROT";
      wr = copy_req(rd);
      wr.m_prot = rd.m_prot ^ 3'b001;
    end
  endcase

  send_expect(rd, 1'b0, RespExOkay, $sformatf("exclusive read before a write with another %0s",
                                              what));
  send_expect(wr, 1'b1, RespOkay, $sformatf("exclusive write with another %0s", what));
  send_expect(rd, 1'b1, RespExOkay, $sformatf("matching exclusive write after one with another %0s",
                                              what));
endtask : mismatched_write

task axi_agent_exclusive_vseq::moved_monitor(bit with_error);
  axi_agent_rand_req excl = new_excl_req();
  axi_agent_rand_req other = copy_req(excl);
  axi_agent_rand_req plain = copy_req(excl);
  axi_sub_agent_cfg  sub_cfg = cfg.m_sub_agent_cfg;
  int unsigned       bytes = (int'(excl.m_len) + 1) << excl.m_size;
  string             what = with_error ? "an exclusive read with its ID that took an error" :
                                         "another exclusive read with its ID";

  // Use the other half of a size-aligned block twice the exclusive access size (A7.2.4), with
  // disjoint bytes in the same 4KB page
  other.m_addr = excl.m_addr ^ bytes;
  plain.m_lock = 1'b0;

  send_expect(excl, 1'b0, RespExOkay, $sformatf("exclusive read before %0s", what));
  if (with_error) begin
    sub_cfg.m_err_addr_valid = 1'b1;
    sub_cfg.m_err_addr       = other.m_addr;
    sub_cfg.m_err_addr_mask  = bytes - 1;
    send_expect(other, 1'b0, sub_cfg.m_err_resp, what);
  end else begin
    send_expect(other, 1'b0, RespExOkay, what);
  end
  send_expect(excl, 1'b1, RespOkay, $sformatf("exclusive write after %0s", what));

  // Read back to check that the failed write left memory unchanged
  send_expect(plain, 1'b0, RespOkay, $sformatf("read of an exclusive write after %0s", what));
  sub_cfg.m_err_addr_valid = 1'b0;
endtask : moved_monitor

task axi_agent_exclusive_vseq::top_of_address_space();
  axi_agent_rand_req excl = new_excl_req();
  axi_agent_rand_req plain;

  excl.m_addr  = '1 << 3;
  excl.m_len   = 0;
  excl.m_size  = 3;
  excl.m_burst = BurstIncr;
  plain = copy_req(excl);
  plain.m_lock = 1'b0;
  plain.m_id   = excl.m_id ^ 1;

  send_expect(excl, 1'b0, RespExOkay, "exclusive read at the top of the address space");
  send_expect(plain, 1'b1, RespOkay, "normal write at the top of the address space");
  send_expect(excl, 1'b1, RespOkay, "exclusive write after a normal write to its bytes");
endtask : top_of_address_space

task axi_agent_exclusive_vseq::write_during_read();
  axi_agent_rand_req         excl = new_excl_req();
  axi_agent_rand_req         plain = copy_req(excl);
  axi_sub_agent_cfg          sub_cfg = cfg.m_sub_agent_cfg;
  virtual axi_agent_probe_if probe = cfg.m_probe_vif;
  int unsigned               latency = sub_cfg.m_default_latency;
  bit                        predict_reads = cfg.m_link.m_predict_reads;
  int unsigned               ar_before, r_before;

  plain.m_lock = 1'b0;
  plain.m_id   = excl.m_id ^ 1;

  // The read returns its bytes from before the write, which the reference memory no longer holds
  cfg.m_link.m_predict_reads = 1'b0;
  sub_cfg.m_default_latency  = 200;
  wait_ready();
  ar_before = probe.m_ar_handshakes;
  r_before  = probe.m_r_handshakes;
  fork
    send_expect(excl, 1'b0, RespExOkay, "exclusive read held while a write changes its bytes");
    begin
      // Restore the latency after the edge at which the read took it
      wait (probe.m_ar_handshakes != ar_before);
      @(posedge cfg.clk_rst_vif.clk);
      sub_cfg.m_default_latency = latency;
      send_expect(plain, 1'b1, RespOkay, "normal write while an exclusive read waits for data");
      if (probe.m_r_handshakes != r_before) begin
        `uvm_error(get_full_name(), "The exclusive read completed before the write to its bytes.")
      end
    end
  join
  @(posedge cfg.clk_rst_vif.clk);
  cfg.m_link.m_predict_reads = predict_reads;
  send_expect(excl, 1'b1, RespOkay, "exclusive write after a write made during its read");
endtask : write_during_read

task axi_agent_exclusive_vseq::unordered_write();
  axi_agent_rand_req         excl = new_excl_req();
  axi_agent_rand_req         plain = copy_req(excl);
  axi_sub_ready_cfg          w_ready = cfg.m_sub_agent_cfg.m_w_ready;
  int unsigned               ready_pct = w_ready.m_ready_before_valid_pct;
  int unsigned               min_delay = w_ready.m_min_valid_to_ready;
  int unsigned               max_delay = w_ready.m_max_valid_to_ready;
  virtual axi_agent_probe_if probe = cfg.m_probe_vif;
  bit                        predict_reads = cfg.m_link.m_predict_reads;
  int unsigned               aw_before, w_before, ar_before;

  plain.m_lock = 1'b0;
  plain.m_id   = excl.m_id ^ 1;

  // The read may return the bytes from before or after the write (A6.1)
  cfg.m_link.m_predict_reads       = 1'b0;
  w_ready.m_ready_before_valid_pct = 0;
  w_ready.m_min_valid_to_ready     = 50;
  w_ready.m_max_valid_to_ready     = 50;
  wait_ready();
  aw_before = probe.m_aw_handshakes;
  w_before  = probe.m_w_handshakes;
  ar_before = probe.m_ar_handshakes;
  fork
    send_expect(plain, 1'b1, RespOkay, "normal write whose data waits for an exclusive read");
    begin
      wait (probe.m_aw_handshakes != aw_before);
      fork
        send_expect(excl, 1'b0, RespExOkay, "exclusive read while a write to its bytes waits");
        begin
          wait (probe.m_ar_handshakes != ar_before);
          if (probe.m_w_handshakes != w_before) begin
            `uvm_error(get_full_name(), "The write's data was accepted before the exclusive read.")
          end
        end
      join
    end
  join
  @(posedge cfg.clk_rst_vif.clk);
  w_ready.m_ready_before_valid_pct = ready_pct;
  w_ready.m_min_valid_to_ready     = min_delay;
  w_ready.m_max_valid_to_ready     = max_delay;
  cfg.m_link.m_predict_reads       = predict_reads;

  // The subordinate took the write's data after the read, so the write ended the monitor
  send_expect(excl, 1'b1, RespOkay, "exclusive write after a write in flight at its read");
  send_expect(excl, 1'b1, RespOkay, "second exclusive write after the same exclusive read");

  // Read back to check that neither exclusive write changed memory
  send_expect(plain, 1'b0, RespOkay, "read of two failed exclusive writes");
endtask : unordered_write

task axi_agent_exclusive_vseq::body();
  int unsigned num_mismatches = 5 * m_num_rounds;
  int unsigned num_failures = 4 * m_num_rounds + num_mismatches + 3;
  bit          addr64 = (cfg.m_addr_width == 64);

  need("exokay_responses", 5 * m_num_rounds + 2 * num_mismatches + 2);
  need("exclusive_failures", num_failures);
  need("exclusive_requests", 13 * m_num_rounds + 3 * num_mismatches + 5);
  need("exclusive_unordered", 1);

  cfg.m_sub_agent_cfg.m_exclusive_support = 1'b1;
  repeat (m_num_rounds) begin
    axi_agent_rand_req excl = new_excl_req();
    axi_agent_rand_req plain = copy_req(excl);

    // An exclusive read, then the matching exclusive write: EXOKAY for both
    send_expect(excl, 1'b0, RespExOkay, "exclusive read");
    send_expect(excl, 1'b1, RespExOkay, "matching exclusive write");

    // An exclusive read, a normal write over the same bytes, then the exclusive write: OKAY
    send_expect(excl, 1'b0, RespExOkay, "exclusive read");
    plain.m_lock = 1'b0;
    plain.m_id   = excl.m_id ^ 1;
    send_expect(plain, 1'b1, RespOkay, "normal write over an exclusive read");
    send_expect(excl, 1'b1, RespOkay, "exclusive write after a normal write to its bytes");

    // An exclusive write with no exclusive read before it: OKAY
    excl = new_excl_req();
    send_expect(excl, 1'b1, RespOkay, "exclusive write with no exclusive read");

    // An intervening same-ID exclusive read, successful or failed, makes the write return OKAY
    moved_monitor(1'b0);
    moved_monitor(1'b1);
  end
  for (int unsigned i = 0; i < num_mismatches; i++) begin
    mismatched_write(i % 5);
  end
  write_during_read();
  unordered_write();
  if (addr64) begin
    need("exclusive_failures", num_failures + 1);
    top_of_address_space();
  end

  // Without exclusive support, return OKAY and carry out writes. Switch it off at an edge, so the
  // scoreboard checks the last exclusive write with it on.
  wait_ready();
  cfg.m_sub_agent_cfg.m_exclusive_support = 1'b0;
  repeat (m_num_rounds) begin
    axi_agent_rand_req excl = new_excl_req();

    send_expect(excl, 1'b0, RespOkay, "exclusive read without exclusive support");
    send_expect(excl, 1'b1, RespOkay, "exclusive write without exclusive support");
  end
endtask : body
