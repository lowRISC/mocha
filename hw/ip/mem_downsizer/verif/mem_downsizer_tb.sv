// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`timescale 1ns/1ps

/* verilator lint_off DECLFILENAME */

// Interface for interacting with the upstream (host) side of the DUT
interface mem64_if (input logic clk);
  logic              req;
  logic              gnt;
  logic              we;
  logic [(64/8)-1:0] be;
  logic [    32-1:0] addr;
  logic [    64-1:0] wdata;
  logic              rvalid;
  logic [    64-1:0] rdata;

  modport host (
    input  clk,
    input  req,
    input  gnt,
    input  rvalid,
    input  rdata
  );

  modport dut (
    input  req,
    input  we,
    input  be,
    input  addr,
    input  wdata,
    output gnt,
    output rvalid,
    output rdata
  );
endinterface

// Interface for interacting with the downstream (device) side of the DUT
interface mem32_if (input logic clk);
  logic              req;
  logic              gnt;
  logic              we;
  logic [(32/8)-1:0] be;
  logic [    32-1:0] addr;
  logic [    32-1:0] wdata;
  logic              rvalid;
  logic [    32-1:0] rdata;

  modport device (
    input  clk,
    input  req,
    input  we,
    input  be,
    input  addr,
    input  wdata,
    input  gnt,
    input  rvalid,
    input  rdata
  );

  modport dut (
    output req,
    input  gnt,
    output we,
    output be,
    output addr,
    output wdata,
    input  rvalid,
    input  rdata
  );
endinterface

// Driver class for interacting with the upstream (host) via the interface above
// Provides convenient methods for initiating transactions and awaiting their completion
class mem64_host_driver;
  virtual mem64_if.host vif;

  function new(virtual mem64_if.host vif);
    this.vif = vif;
  endfunction

  task automatic reset_host();
    @(posedge vif.clk);
    vif.req   <= 1'b0;
    vif.we    <= 1'b0;
    vif.be    <= '0;
    vif.addr  <= '0;
    vif.wdata <= '0;
  endtask

  task automatic begin_write(
    input logic [32-1:0] addr,
    input logic [64-1:0] data,
    input logic [(64/8)-1:0] be
  );
    vif.addr  <= addr;
    vif.wdata <= data;
    vif.be    <= be;
    vif.we    <= 1'b1;
    vif.req   <= 1'b1;
  endtask

  task automatic begin_read(input logic [32-1:0] addr);
    vif.addr  <= addr;
    vif.wdata <= '0;
    vif.be    <= '0;
    vif.we    <= 1'b0;
    vif.req   <= 1'b1;
  endtask

  task automatic await_request_accept();
    int unsigned cycles;
    cycles = 0;
    do begin
      @(posedge vif.clk);
      cycles++;
      if (cycles > 500) begin
        $error(1, "Timeout waiting for mem64 request acceptance");
      end
    end while (!vif.gnt);

    vif.req <= 1'b0;
  endtask

  task automatic await_read_completion(output logic [64-1:0] rdata);
    int unsigned cycles;
    cycles = 0;
    do begin
      @(posedge vif.clk);
      cycles++;
      if (cycles > 1000) begin
        $error(1, "Timeout waiting for mem64 read completion");
      end
    end while (!vif.rvalid);
    rdata = vif.rdata;
  endtask
endclass

// Dummy model of a downstream device that responds to 32-bit memory requests with configurable delays
// Delay for both granting requests and returning read data can be configured using gnt_delay_i and rvalid_delay_i
// Maintains a queue (non-synthesisable) of pending read responses meaning an arbitrary number of reads can be accepted before the first one completes
// Maintains an internal memory ("mem_words") to allow the testbench to read back writes
module mem32_dummy_device_model (
  input  logic              clk_i,
  input  logic              rst_ni,
  input  logic              req_i,
  input  logic              we_i,
  input  logic [(32/8)-1:0] be_i,
  input  logic [    32-1:0] addr_i,
  input  logic [    32-1:0] wdata_i,
  output logic              gnt_o,
  output logic              rvalid_o,
  output logic [    32-1:0] rdata_o,

  // Configuration for tests
  input  integer            gnt_delay_i, // 0 = combinatorial grant; -1 = always grant; >0 = delay cycles before granting
  input  integer            rvalid_delay_i // must be >=1
);
  typedef struct {
    int unsigned delay;
    logic [32-1:0] data;
  } pending_rsp_t;

  pending_rsp_t pending_rsp_q[$];

  logic [32-1:0] mem_words [longint unsigned];

  bit req_inflight;
  bit gnt_pending;
  int gnt_countdown;
  logic gnt_pulse_q;
  logic [32-1:0] req_addr_q;
  logic [32-1:0] req_wdata_q;
  logic req_we_q;
  logic [(32/8)-1:0] req_be_q;

  function logic [32-1:0] default_read_data(input logic [32-1:0] addr);
    return 32'hA500_0000 ^ addr;
  endfunction

  function void apply_write(
    input logic [32-1:0] addr,
    input logic [32-1:0] wdata,
    input logic [(32/8)-1:0] be
  );
    longint unsigned word_idx;
    logic [32-1:0] cur;
    int i;

    word_idx = (longint'(addr)) >> 2;
    cur = mem_words.exists(word_idx) ? mem_words[word_idx] : default_read_data(addr);
    for (i = 0; i < (32/8); i++) begin
      if (be[i]) begin
        cur[i*8 +: 8] = wdata[i*8 +: 8];
      end
    end
    mem_words[word_idx] = cur;
  endfunction

  function logic [32-1:0] read_word(input logic [32-1:0] addr);
    longint unsigned word_idx;
    word_idx = (longint'(addr)) >> 2;
    if (mem_words.exists(word_idx)) begin
      return mem_words[word_idx];
    end
    return default_read_data(addr);
  endfunction

  function automatic int unsigned sanitize_delay(input integer raw_delay);
    if (raw_delay < 0) begin
      return 0;
    end
    return raw_delay;
  endfunction

  // For gnt_delay_i == 0, assert grant immediately as combinational ready.
  // For gnt_delay_i == -1, assert grant constantly regardless of req.
  assign gnt_o = (gnt_delay_i == -1) ? 1'b1 :
                 ((gnt_delay_i == 0 && req_i) ? 1'b1 : gnt_pulse_q);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    bit handshake;
    int unsigned sampled_rsp_delay;
    logic [32-1:0] rd;

    if (!rst_ni) begin
      req_inflight  <= 1'b0;
      gnt_pending   <= 1'b0;
      gnt_countdown <= 0;
      gnt_pulse_q   <= 1'b0;
      rvalid_o      <= 1'b0;
      rdata_o       <= '0;
      pending_rsp_q.delete();
      mem_words.delete();
    end else begin
      gnt_pulse_q <= 1'b0;
      rvalid_o    <= 1'b0;

      // Protocol checks for upstream requester behavior.
      if (req_inflight) begin
        assert (req_i)
          else $error(1, "dummy_device: req deasserted before gnt/handshake");
        assert (addr_i == req_addr_q)
          else $error(1, "dummy_device: addr changed while waiting for handshake");
        assert (wdata_i == req_wdata_q)
          else $error(1, "dummy_device: wdata changed while waiting for handshake");
        assert (we_i == req_we_q)
          else $error(1, "dummy_device: we changed while waiting for handshake");
        assert (be_i == req_be_q)
          else $error(1, "dummy_device: be changed while waiting for handshake");
      end

      if (pending_rsp_q.size() > 0) begin
        if (pending_rsp_q[0].delay == 0) begin
          rvalid_o <= 1'b1;
          rdata_o  <= pending_rsp_q[0].data;
          void'(pending_rsp_q.pop_front());
        end else begin
          pending_rsp_q[0].delay--;
        end
      end

      if (!req_i) begin
        if (gnt_delay_i != -1) begin
          gnt_pending <= 1'b0;
        end
      end

      if (req_i && gnt_delay_i > 0 && !gnt_pending) begin
        gnt_pending   <= 1'b1;
        gnt_countdown <= gnt_delay_i;
      end

      if (gnt_pending) begin
        if (!req_i) begin
          gnt_pending <= 1'b0;
        end else if (gnt_countdown == 1) begin
          gnt_pending <= 1'b0;
          gnt_pulse_q <= 1'b1;
        end else begin
          gnt_countdown <= gnt_countdown - 1;
        end
      end

      handshake = req_i && gnt_o;

      if (!req_inflight && req_i && !handshake) begin
        req_inflight <= 1'b1;
        req_addr_q   <= addr_i;
        req_wdata_q  <= wdata_i;
        req_we_q     <= we_i;
        req_be_q     <= be_i;
      end

      if (handshake) begin
        req_inflight <= 1'b0;
        if (we_i) begin
          apply_write(addr_i, wdata_i, be_i);
        end else begin
          rd = read_word(addr_i);
          sampled_rsp_delay = sanitize_delay(rvalid_delay_i);
          if (sampled_rsp_delay == 0) begin
            rvalid_o <= 1'b1;
            rdata_o  <= rd;
          end else begin
            pending_rsp_q.push_back('{delay: sampled_rsp_delay, data: rd});
          end
        end
      end
    end
  end
endmodule

/* verilator lint_on DECLFILENAME */

// The main testbench which instantiates the upstream and downstream interfaces
// The downstream interface is connected to the dummy SRAM-ish device
// The upstream interface is connected to a driver object which the TB uses

// Functions in this module monitor the transactions ("observe") for use by test cases
// An 'initial' block is responsible for calling each test in succession
module mem_downsizer_tb;
  typedef struct packed {
    logic                          we;
    logic [32-1:0]     addr;
    logic [32-1:0]     wdata;
    logic [(32/8)-1:0] be;
  } mem32_txn_t;

  logic clk_i;
  logic rst_ni;
  integer gnt_delay_cfg;
  integer rvalid_delay_cfg;

  mem64_if mem64_bus(clk_i);
  mem32_if mem32_bus(clk_i);

  mem64_host_driver host;
  mem32_txn_t observed_q[$];

  mem_downsizer #(
    .UPSTREAM_DATA_W(64),
    .ADDR_W(32)
  ) dut (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .mem_req_i   (mem64_bus.req),
    .mem_gnt_o   (mem64_bus.gnt),
    .mem_we_i    (mem64_bus.we),
    .mem_be_i    (mem64_bus.be),
    .mem_addr_i  (mem64_bus.addr),
    .mem_wdata_i (mem64_bus.wdata),
    .mem_rvalid_o(mem64_bus.rvalid),
    .mem_rdata_o (mem64_bus.rdata),
    .mem_req_o   (mem32_bus.req),
    .mem_gnt_i   (mem32_bus.gnt),
    .mem_we_o    (mem32_bus.we),
    .mem_be_o    (mem32_bus.be),
    .mem_addr_o  (mem32_bus.addr),
    .mem_wdata_o (mem32_bus.wdata),
    .mem_rvalid_i(mem32_bus.rvalid),
    .mem_rdata_i (mem32_bus.rdata)
  );

  mem32_dummy_device_model dummy_device (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .req_i        (mem32_bus.req),
    .we_i         (mem32_bus.we),
    .be_i         (mem32_bus.be),
    .addr_i       (mem32_bus.addr),
    .wdata_i      (mem32_bus.wdata),
    .gnt_delay_i  (gnt_delay_cfg),
    .rvalid_delay_i(rvalid_delay_cfg),
    .gnt_o        (mem32_bus.gnt),
    .rvalid_o     (mem32_bus.rvalid),
    .rdata_o      (mem32_bus.rdata)
  );

  always #5 clk_i = ~clk_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    mem32_txn_t tx;
    if (!rst_ni) begin
      observed_q.delete();
    end else if (mem32_bus.req && mem32_bus.gnt) begin
      tx.we    = mem32_bus.we;
      tx.addr  = mem32_bus.addr;
      tx.wdata = mem32_bus.wdata;
      tx.be    = mem32_bus.be;
      observed_q.push_back(tx);
    end
  end

  task automatic clear_observed_transactions();
    observed_q.delete();
  endtask

  function automatic int unsigned observed_count();
    return observed_q.size();
  endfunction

  function automatic mem32_txn_t observed_at(input int unsigned idx);
    if (idx >= observed_q.size()) begin
      $error(1, "Observed transaction index %0d out of range (size=%0d)", idx, observed_q.size());
    end
    return observed_q[idx];
  endfunction

  task automatic wait_for_observed_count(
    input int unsigned expected_count,
    input int unsigned timeout_cycles,
    input string test_name
  );
    int unsigned cycles;
    cycles = 0;
    while (observed_count() < expected_count) begin
      @(posedge clk_i);
      cycles++;
      if (cycles > timeout_cycles) begin
        $error(1,
               "%s: timeout waiting for %0d observed txns (saw %0d)",
               test_name, expected_count, observed_count());
      end
    end
  endtask

  task automatic wait_for_reset_release();
    repeat (4) @(posedge clk_i);
    rst_ni = 1'b1;
    repeat (2) @(posedge clk_i);
  endtask

  task automatic test_write_split();
    mem32_txn_t tx0;
    mem32_txn_t tx1;

    $display("[TB] test_write_split: start");
    clear_observed_transactions();

    host.begin_write(32'h0000_0100, 64'h1122_3344_5566_7788, 8'hFF);
    host.await_request_accept();

    wait_for_observed_count(2, 200, "test_write_split");

    tx0 = observed_at(0);
    tx1 = observed_at(1);

    if (!tx0.we || tx0.addr != 32'h0000_0100 || tx0.wdata != 32'h55667788 || tx0.be != 4'hF) begin
      $error(1,
             "test_write_split: first 32-bit txn mismatch we=%0b addr=%h data=%h be=%h",
             tx0.we, tx0.addr, tx0.wdata, tx0.be);
    end

    if (!tx1.we || tx1.addr != 32'h0000_0104 || tx1.wdata != 32'h11223344 || tx1.be != 4'hF) begin
      $error(1,
             "test_write_split: second 32-bit txn mismatch we=%0b addr=%h data=%h be=%h",
             tx1.we, tx1.addr, tx1.wdata, tx1.be);
    end

    repeat (3) @(posedge clk_i);
    if (mem64_bus.rvalid !== 1'b0) begin
      $error(1, "test_write_split: write should not generate mem64 rvalid");
    end

    $display("[TB] test_write_split: pass");
  endtask

  task automatic test_read_merge();
    logic [64-1:0] rd;
    int unsigned base_count;

    $display("[TB] test_read_merge: start");

    base_count = observed_count();

    // Preload both 32-bit words through writes so readback value is deterministic.
    host.begin_write(32'h0000_0200, 64'hCAFE_BABE_DEAD_BEEF, 8'hFF);
    host.await_request_accept();
    wait_for_observed_count(base_count + 2, 200, "test_read_merge preload");

    host.begin_read(32'h0000_0200);
    host.await_request_accept();
    host.await_read_completion(rd);

    if (rd !== 64'hCAFE_BABE_DEAD_BEEF) begin
      $error(1, "test_read_merge: expected %h got %h", 64'hCAFE_BABE_DEAD_BEEF, rd);
    end

    $display("[TB] test_read_merge: pass");
  endtask

  task automatic test_partial_write_be_forwarding();
    int unsigned base_count;
    mem32_txn_t tx0;
    mem32_txn_t tx1;

    $display("[TB] test_partial_write_be_forwarding: start");

    base_count = observed_count();

    // Use a non-full-width byte-enable so both downstream 32-bit nibbles are exercised.
    host.begin_write(32'h0000_0240, 64'hFEDC_BA98_7654_3210, 8'hA5);
    host.await_request_accept();

    wait_for_observed_count(base_count + 2, 200, "test_partial_write_be_forwarding");

    tx0 = observed_at(base_count + 0);
    tx1 = observed_at(base_count + 1);

    if (!tx0.we || tx0.addr != 32'h0000_0240 || tx0.wdata != 32'h7654_3210 || tx0.be != 4'h5) begin
      $error(1,
             "test_partial_write_be_forwarding: low-half mismatch we=%0b addr=%h data=%h be=%h",
             tx0.we, tx0.addr, tx0.wdata, tx0.be);
    end

    if (!tx1.we || tx1.addr != 32'h0000_0244 || tx1.wdata != 32'hFEDC_BA98 || tx1.be != 4'hA) begin
      $error(1,
             "test_partial_write_be_forwarding: high-half mismatch we=%0b addr=%h data=%h be=%h",
             tx1.we, tx1.addr, tx1.wdata, tx1.be);
    end

    $display("[TB] test_partial_write_be_forwarding: pass");
  endtask

  task automatic test_halfword_write();
    // If a halfword write occurs (i.e. be[3:0]=0 or be[7:4]=0),
    // the downsizer should NOT issue a downstream write for the halfword that is not enabled.
    int unsigned base_count;
    mem32_txn_t tx0,tx1,tx2,tx3;

    $display("[TB] test_halfword_write: start");

    base_count = observed_count();

    // Write with only upper halfword enabled
    host.begin_write(32'h0000_0280, 64'hAABB_CCDD_BADD_BADD, 8'hF0);
    host.await_request_accept();
    // Write with only lower halfword enabled
    host.begin_write(32'h0000_0290, 64'hBADD_BADD_900D_F00D, 8'h0F);
    host.await_request_accept();
    // Write a full word
    host.begin_write(32'h0000_0300, 64'h900D_BEEF_CAFE_BEEF, 8'hF3);
    host.await_request_accept();

    wait_for_observed_count(base_count + 4, 200, "test_halfword_write"); // expect four new transactions: one for the first write, one for the second, two for the third

    tx0 = observed_at(base_count + 0);
    tx1 = observed_at(base_count + 1);
    tx2 = observed_at(base_count + 2);
    tx3 = observed_at(base_count + 3);

    if (!tx0.we || tx0.addr != 32'h0000_0284 || tx0.wdata != 32'hAABB_CCDD || tx0.be != 4'hF) begin
      $error(1,
             "test_halfword_write: upper-half mismatch we=%0b addr=%h data=%h be=%h",
             tx0.we, tx0.addr, tx0.wdata, tx0.be);
    end
    if (!tx1.we || tx1.addr != 32'h0000_0290 || tx1.wdata != 32'h900D_F00D || tx1.be != 4'hF) begin
      $error(1,
             "test_halfword_write: upper-half mismatch we=%0b addr=%h data=%h be=%h",
             tx1.we, tx1.addr, tx1.wdata, tx1.be);
    end
    if (!tx2.we || tx2.addr != 32'h0000_0300 || tx2.wdata != 32'hCAFE_BEEF || tx2.be != 4'h3) begin
      $error(1,
             "test_halfword_write: low-half mismatch we=%0b addr=%h data=%h be=%h",
             tx2.we, tx2.addr, tx2.wdata, tx2.be);
    end
    if (!tx3.we || tx3.addr != 32'h0000_0304 || tx3.wdata != 32'h900D_BEEF || tx3.be != 4'hF) begin
      $error(1,
             "test_halfword_write: high-half mismatch we=%0b addr=%h data=%h be=%h",
             tx3.we, tx3.addr, tx3.wdata, tx3.be);
    end

    $display("[TB] test_halfword_write: pass");
  endtask

  task automatic test_proactive_grant();
    int unsigned base_count;
    mem32_txn_t tx0;
    mem32_txn_t tx1;

    $display("[TB] test_proactive_grant: start");

    base_count = observed_count();
    gnt_delay_cfg = -1;

    // With proactive gnt already asserted, the downsizer should still split and accept the request normally.
    host.begin_write(32'h0000_0260, 64'h0123_4567_89AB_CDEF, 8'hFF);
    host.await_request_accept();

    wait_for_observed_count(base_count + 2, 200, "test_proactive_grant");

    tx0 = observed_at(base_count + 0);
    tx1 = observed_at(base_count + 1);

    if (!tx0.we || tx0.addr != 32'h0000_0260 || tx0.wdata != 32'h89AB_CDEF || tx0.be != 4'hF) begin
      $error(1,
             "test_proactive_grant: low-half mismatch we=%0b addr=%h data=%h be=%h",
             tx0.we, tx0.addr, tx0.wdata, tx0.be);
    end

    if (!tx1.we || tx1.addr != 32'h0000_0264 || tx1.wdata != 32'h0123_4567 || tx1.be != 4'hF) begin
      $error(1,
             "test_proactive_grant: high-half mismatch we=%0b addr=%h data=%h be=%h",
             tx1.we, tx1.addr, tx1.wdata, tx1.be);
    end

    gnt_delay_cfg = 0;

    $display("[TB] test_proactive_grant: pass");
  endtask

  task automatic test_back_to_back_writes();
    int unsigned base_count;
    mem32_txn_t tx0;
    mem32_txn_t tx1;
    mem32_txn_t tx2;
    mem32_txn_t tx3;

    $display("[TB] test_back_to_back_writes: start");

    base_count = observed_count();

    host.begin_write(32'h0000_0300, 64'h0102_0304_0506_0708, 8'hFF);
    host.await_request_accept();
    host.begin_write(32'h0000_0310, 64'h1112_1314_1516_1718, 8'hFF);
    host.await_request_accept();

    wait_for_observed_count(base_count + 4, 300, "test_back_to_back_writes");

    tx0 = observed_at(base_count + 0);
    tx1 = observed_at(base_count + 1);
    tx2 = observed_at(base_count + 2);
    tx3 = observed_at(base_count + 3);

    if (!tx0.we || tx0.addr != 32'h0000_0300 || tx0.wdata != 32'h0506_0708) begin
      $error(1, "test_back_to_back_writes: txn0 mismatch addr=%h data=%h we=%0b",
             tx0.addr, tx0.wdata, tx0.we);
    end
    if (!tx1.we || tx1.addr != 32'h0000_0304 || tx1.wdata != 32'h0102_0304) begin
      $error(1, "test_back_to_back_writes: txn1 mismatch addr=%h data=%h we=%0b",
             tx1.addr, tx1.wdata, tx1.we);
    end
    if (!tx2.we || tx2.addr != 32'h0000_0310 || tx2.wdata != 32'h1516_1718) begin
      $error(1, "test_back_to_back_writes: txn2 mismatch addr=%h data=%h we=%0b",
             tx2.addr, tx2.wdata, tx2.we);
    end
    if (!tx3.we || tx3.addr != 32'h0000_0314 || tx3.wdata != 32'h1112_1314) begin
      $error(1, "test_back_to_back_writes: txn3 mismatch addr=%h data=%h we=%0b",
             tx3.addr, tx3.wdata, tx3.we);
    end

    $display("[TB] test_back_to_back_writes: pass");
  endtask

  task automatic test_back_to_back_reads_outstanding();
    logic [64-1:0] rd0;
    logic [64-1:0] rd1;
    logic [64-1:0] rd2;
    logic [64-1:0] rd3;

    $display("[TB] test_back_to_back_reads_outstanding: start");

    // Preload deterministic content at these addresses.
    host.begin_write(32'h0000_0400, 64'hAAAA_BBBB_CCCC_DDDD, 8'hFF);
    host.await_request_accept();
    host.begin_write(32'h0000_0420, 64'hDEAD_BEEF_CAFE_BABE, 8'hFF);
    host.await_request_accept();
    host.begin_write(32'h0000_0410, 64'h1234_5678_9ABC_DEF0, 8'hFF);
    host.await_request_accept();
    host.begin_write(32'h0000_0430, 64'h5000_4000_3000_2000, 8'hFF);
    host.await_request_accept();

    // Issue reads with independent completion checks
    fork
      begin // issue reads
        host.begin_read(32'h0000_0400);
        host.await_request_accept();
        host.begin_read(32'h0000_0410);
        host.await_request_accept();
        host.begin_read(32'h0000_0420);
        host.await_request_accept();
        host.begin_read(32'h0000_0430);
        host.await_request_accept();
      end
      begin // await responses in a separate thread
        host.await_read_completion(rd0);
        host.await_read_completion(rd1);
        host.await_read_completion(rd2);
        host.await_read_completion(rd3);
      end
    join

    if (rd0 !== 64'hAAAA_BBBB_CCCC_DDDD) begin
      $error(1, "test_back_to_back_reads_outstanding: rd0 mismatch exp=%h got=%h",
             64'hAAAA_BBBB_CCCC_DDDD, rd0);
    end
    if (rd1 !== 64'h1234_5678_9ABC_DEF0) begin
      $error(1, "test_back_to_back_reads_outstanding: rd1 mismatch exp=%h got=%h",
             64'h1234_5678_9ABC_DEF0, rd1);
    end
    if (rd2 !== 64'hDEAD_BEEF_CAFE_BABE) begin
      $error(1, "test_back_to_back_reads_outstanding: rd2 mismatch exp=%h got=%h",
             64'hDEAD_BEEF_CAFE_BABE, rd2);
    end
    if (rd3 !== 64'h5000_4000_3000_2000) begin
      $error(1, "test_back_to_back_reads_outstanding: rd3 mismatch exp=%h got=%h",
             64'h5000_4000_3000_2000, rd3);
    end

    $display("[TB] test_back_to_back_reads_outstanding: pass");
  endtask

  task automatic test_latency_combinations();
    logic [64-1:0] rd;
    logic [31:0] addr32;
    logic [63:0] data64;
    int unsigned combo_idx;
    int unsigned idx32;
    int gnt_d;
    int rsp_d;

    $display("[TB] test_latency_combinations: start");

    for (gnt_d = 0; gnt_d <= 2; gnt_d++) begin
      for (rsp_d = 1; rsp_d <= 3; rsp_d++) begin
        $display("[TB] test_latency_combinations: gnt=%0d rsp=%0d", gnt_d, rsp_d);
        gnt_delay_cfg = gnt_d;
        rvalid_delay_cfg = rsp_d;
        combo_idx = (gnt_d * 3) + (rsp_d - 1);
        idx32 = int'(combo_idx);
        addr32 = 32'h0000_0500 + (idx32 << 4);
        data64 = 64'hD000_0000_0000_0000 | (64'(gnt_d) << 8) | 64'(rsp_d);

        host.begin_write(addr32, data64, 8'hFF);
        host.await_request_accept();

        host.begin_read(addr32);
        host.await_request_accept();
        host.await_read_completion(rd);

        if (rd !== data64) begin
          $error(1,
                 "test_latency_combinations: gnt=%0d rsp=%0d expected=%h got=%h",
                 gnt_d, rsp_d, data64, rd);
        end
      end
    end

    // Restore randomized behavior for any future tests.
    gnt_delay_cfg = 0;
    rvalid_delay_cfg = 1;

    $display("[TB] test_latency_combinations: pass");
  endtask

  initial begin
    clk_i  = 1'b0;
    rst_ni = 1'b0;
    gnt_delay_cfg = 0;
    rvalid_delay_cfg = 1;

    host = new(mem64_bus.host);
    host.reset_host();

    wait_for_reset_release();

    test_write_split();
    test_read_merge();
    test_partial_write_be_forwarding();
    test_proactive_grant();
    test_latency_combinations();
    test_back_to_back_writes();
    test_back_to_back_reads_outstanding();

    //test_halfword_write();
    // This test is currently for a feature not yet implemented but is preserved here for future TDD

    $display("mem_downsizer_tb: ALL TESTS PASSED");
    $finish;
  end

  initial begin
    $dumpfile("mem_downsizer_tb.vcd");
    $dumpvars(0, mem_downsizer_tb);
  end
endmodule
