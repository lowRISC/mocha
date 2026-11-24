// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check AXI Manager obligations from AMBA AXI H.c (assertion comments cite the checked sections)
`include "prim_assert.sv"

interface axi_mgr_protocol_sva_if
  import axi_widths_pkg::*;
(
  input logic                           clk_i,
  input logic                           rst_ni,

  input logic                           awvalid,
  input logic                           awready,
  input logic [AxiMaxIdWidth-1:0]       awid,
  input logic [AxiMaxAddrWidth-1:0]     awaddr,
  input logic [AxiRegionWidth-1:0]      awregion,
  input logic [AxiLenWidth-1:0]         awlen,
  input logic [AxiSizeWidth-1:0]        awsize,
  input logic [AxiBurstWidth-1:0]       awburst,
  input logic                           awlock,
  input logic [AxiCacheWidth-1:0]       awcache,
  input logic [AxiProtWidth-1:0]        awprot,
  input logic [AxiQosWidth-1:0]         awqos,
  input logic [AxiMaxReqUserWidth-1:0]  awuser,

  input logic                           wvalid,
  input logic                           wready,
  input logic [AxiMaxDataWidth-1:0]     wdata,
  input logic [AxiMaxStrbWidth-1:0]     wstrb,
  input logic                           wlast,
  input logic [AxiMaxDataUserWidth-1:0] wuser,

  input logic                           bvalid,
  input logic                           bready,

  input logic                           arvalid,
  input logic                           arready,
  input logic [AxiMaxIdWidth-1:0]       arid,
  input logic [AxiMaxAddrWidth-1:0]     araddr,
  input logic [AxiRegionWidth-1:0]      arregion,
  input logic [AxiLenWidth-1:0]         arlen,
  input logic [AxiSizeWidth-1:0]        arsize,
  input logic [AxiBurstWidth-1:0]       arburst,
  input logic                           arlock,
  input logic [AxiCacheWidth-1:0]       arcache,
  input logic [AxiProtWidth-1:0]        arprot,
  input logic [AxiQosWidth-1:0]         arqos,
  input logic [AxiMaxReqUserWidth-1:0]  aruser,

  input logic                           rvalid,
  input logic                           rready,
  input logic [AxiMaxIdWidth-1:0]       rid,
  input logic                           rlast,

  // Bus properties from the channel interfaces
  input int unsigned                    id_w_width,
  input int unsigned                    id_r_width,
  input int unsigned                    addr_width,
  input int unsigned                    data_width,
  input int unsigned                    aw_user_req_width,
  input int unsigned                    ar_user_req_width,
  input int unsigned                    user_data_width,
  input bit                             is_lite,

  // Settings from axi_if, which documents them with its set_* functions
  input bit                             disable_sva,
  input int unsigned                    max_ready_wait,
  input int unsigned                    max_output_delay_ps,
  input int unsigned                    max_reset_release_delay_ps
);

  // Local AxBURST encodings keep the checker independent
  localparam logic [1:0] BurstFixed = 2'b00;
  localparam logic [1:0] BurstIncr  = 2'b01;
  localparam logic [1:0] BurstWrap  = 2'b10;

  // Use only configured request bits, because higher bits of maximum-width interface signals are
  // undriven
  logic [AxiMaxIdWidth-1:0]       awid_in_use, arid_in_use, rid_in_use;
  logic [AxiMaxAddrWidth-1:0]     awaddr_in_use, araddr_in_use;
  logic [AxiMaxReqUserWidth-1:0]  awuser_in_use, aruser_in_use;
  logic [AxiMaxDataUserWidth-1:0] wuser_in_use;
  logic [AxiMaxStrbWidth-1:0]     wstrb_in_use;
  assign awid_in_use   = awid & ((AxiMaxIdWidth'(1) << id_w_width) - 1);
  assign arid_in_use   = arid & ((AxiMaxIdWidth'(1) << id_r_width) - 1);
  assign rid_in_use    = rid & ((AxiMaxIdWidth'(1) << id_r_width) - 1);
  assign awaddr_in_use = awaddr & ((AxiMaxAddrWidth'(1) << addr_width) - 1);
  assign araddr_in_use = araddr & ((AxiMaxAddrWidth'(1) << addr_width) - 1);
  assign awuser_in_use = awuser & ((AxiMaxReqUserWidth'(1) << aw_user_req_width) - 1);
  assign aruser_in_use = aruser & ((AxiMaxReqUserWidth'(1) << ar_user_req_width) - 1);
  assign wuser_in_use  = wuser & ((AxiMaxDataUserWidth'(1) << user_data_width) - 1);
  // One strobe per data byte (A3.4.4)
  assign wstrb_in_use  = wstrb & ((AxiMaxStrbWidth'(1) << (data_width / 8)) - 1);

  // Only strobed WDATA bytes must remain stable while waiting for WREADY (A3.4.4)
  logic [AxiMaxDataWidth-1:0] wdata_in_use;
  always_comb begin
    wdata_in_use = '0;
    for (int unsigned lane = 0; lane < AxiMaxStrbWidth; lane++) begin
      if (wstrb_in_use[lane] === 1'b1) begin
        wdata_in_use[8 * lane +: 8] = wdata[8 * lane +: 8];
      end
    end
  end

  // ARESETn at the previous edge
  logic rst_q;

  always_ff @(posedge clk_i) begin
    rst_q <= rst_ni;
  end

  // Check burst length, size and alignment (A3.4.1), AxCACHE (A4.4), exclusive restrictions
  // (A7.2.4) and AXI4-Lite defaults (B1.1.1)
  function automatic bit request_is_legal(logic [AxiMaxAddrWidth-1:0] addr,
                                          logic [AxiLenWidth-1:0]     len,
                                          logic [AxiSizeWidth-1:0]    size,
                                          logic [AxiBurstWidth-1:0]   burst,
                                          logic                       lock,
                                          logic [AxiCacheWidth-1:0]   cache);
    int unsigned              nbytes = 1 << size;
    int unsigned              beats  = int'(len) + 1;
    logic [AxiMaxAddrWidth-1:0] last_byte;

    if (nbytes > data_width / 8) begin
      return 1'b0;
    end
    case (burst)
      BurstFixed: begin
        if (beats > 16) begin
          return 1'b0;
        end
      end
      BurstIncr: begin
        last_byte = (((addr >> size) + beats) << size) - 1;
        if ((last_byte >> 12) != (addr >> 12)) begin
          return 1'b0;
        end
      end
      BurstWrap: begin
        if (!(beats inside {2, 4, 8, 16}) || (addr % nbytes) != 0) begin
          return 1'b0;
        end
      end
      default: begin
        return 1'b0;
      end
    endcase
    if (!(cache inside {4'b0000, 4'b0001, 4'b0010, 4'b0011, 4'b0110,
                        4'b0111, 4'b1010, 4'b1011, 4'b1110, 4'b1111})) begin
      return 1'b0;
    end
    if (lock && (!(beats inside {1, 2, 4, 8, 16}) || beats * nbytes > 128 ||
                 (addr % (beats * nbytes)) != 0)) begin
      return 1'b0;
    end
    if (is_lite && (len != 0 || nbytes != data_width / 8 || burst != BurstIncr || lock ||
                    cache != 4'b0000)) begin
      return 1'b0;
    end
    return 1'b1;
  endfunction : request_is_legal

  // Return beat n's lanes (A3.4.1, A3.4.2). FIXED reuses the first beat's lanes, and unaligned
  // beats end at their aligned container's end.
  function automatic logic [AxiMaxStrbWidth-1:0] beat_lanes(logic [AxiMaxAddrWidth-1:0] addr,
                                                            logic [AxiLenWidth-1:0]     len,
                                                            logic [AxiSizeWidth-1:0]    size,
                                                            logic [AxiBurstWidth-1:0]   burst,
                                                            int unsigned                n);
    int unsigned                bus_bytes = data_width / 8;
    int unsigned                nbytes    = 1 << size;
    int unsigned                beats     = int'(len) + 1;
    logic [AxiMaxAddrWidth-1:0] aligned   = (addr / nbytes) * nbytes;
    logic [AxiMaxAddrWidth-1:0] beat_addr = addr;
    logic [AxiMaxAddrWidth-1:0] boundary;
    int unsigned                lower, upper;
    logic [AxiMaxStrbWidth-1:0] lanes = '0;

    // Use offsets within the WRAP region to avoid overflow at the top of the address space
    if (burst == BurstWrap && n > 0) begin
      boundary  = (addr / (nbytes * beats)) * (nbytes * beats);
      beat_addr = boundary + (aligned - boundary + n * nbytes) % (nbytes * beats);
    end else if (burst != BurstFixed && n > 0) begin
      beat_addr = aligned + n * nbytes;
    end
    lower = beat_addr % bus_bytes;
    upper = (beat_addr % nbytes == 0) ? lower + nbytes - 1 : (aligned % bus_bytes) + nbytes - 1;
    for (int unsigned lane = lower; lane <= upper && lane < AxiMaxStrbWidth; lane++) begin
      lanes[lane] = 1'b1;
    end
    return lanes;
  endfunction : beat_lanes

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Handshakes on AW, W and AR
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // Once VALID is high it stays high until the handshake (A3.2.1)
  `ASSERT(AwValidHeld_A, (awvalid === 1'b1 && awready !== 1'b1) |=> awvalid === 1'b1,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(WValidHeld_A, (wvalid === 1'b1 && wready !== 1'b1) |=> wvalid === 1'b1,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(ArValidHeld_A, (arvalid === 1'b1 && arready !== 1'b1) |=> arvalid === 1'b1,
          clk_i, !rst_ni || disable_sva)

  // The information stays stable while VALID waits for READY (A3.2.1)
  `ASSERT(AwStable_A,
          (awvalid === 1'b1 && awready !== 1'b1) |=>
            $stable({awid_in_use, awaddr_in_use, awregion, awlen, awsize, awburst, awlock, awcache,
                     awprot, awqos, awuser_in_use}),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(WStable_A,
          (wvalid === 1'b1 && wready !== 1'b1) |=>
            $stable({wdata_in_use, wstrb_in_use, wlast, wuser_in_use}),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(ArStable_A,
          (arvalid === 1'b1 && arready !== 1'b1) |=>
            $stable({arid_in_use, araddr_in_use, arregion, arlen, arsize, arburst, arlock, arcache,
                     arprot, arqos, aruser_in_use}),
          clk_i, !rst_ni || disable_sva)

  // VALID is low at every edge during reset (A3.1.2)
  `ASSERT(AwLowInReset_A, rst_ni === 1'b0 |-> awvalid === 1'b0, clk_i, disable_sva)
  `ASSERT(WLowInReset_A, rst_ni === 1'b0 |-> wvalid === 1'b0, clk_i, disable_sva)
  `ASSERT(ArLowInReset_A, rst_ni === 1'b0 |-> arvalid === 1'b0, clk_i, disable_sva)

  // VALID cannot rise before a clock edge after reset release, so it must be low at the first edge
  // sampling ARESETn high (A3.1.2, Figure A3-1)
  `ASSERT(AwLowAfterReset_A, (rst_ni === 1'b1 && rst_q === 1'b0) |-> awvalid === 1'b0,
          clk_i, disable_sva)
  `ASSERT(WLowAfterReset_A, (rst_ni === 1'b1 && rst_q === 1'b0) |-> wvalid === 1'b0,
          clk_i, disable_sva)
  `ASSERT(ArLowAfterReset_A, (rst_ni === 1'b1 && rst_q === 1'b0) |-> arvalid === 1'b0,
          clk_i, disable_sva)

  // Require known VALID outside reset and known BREADY/RREADY when VALID is high. This is an
  // X-checking convention, beyond H.c. READY with VALID low is irrelevant and may depend on idle
  // payload.
  `ASSERT(MgrHandshakeKnown_A,
          !$isunknown({awvalid, wvalid, arvalid}) &&
          (bvalid !== 1'b1 || !$isunknown(bready)) && (rvalid !== 1'b1 || !$isunknown(rready)),
          clk_i, !rst_ni || disable_sva)

  // Require known request control fields while VALID is high, an X-checking convention beyond H.c
  // (see MgrHandshakeKnown_A)
  `ASSERT(AwControlKnown_A,
          awvalid === 1'b1 |->
            !$isunknown({awid_in_use, awaddr_in_use, awlen, awsize, awburst, awlock, awcache}),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(ArControlKnown_A,
          arvalid === 1'b1 |->
            !$isunknown({arid_in_use, araddr_in_use, arlen, arsize, arburst, arlock, arcache}),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(WControlKnown_A, wvalid === 1'b1 |-> !$isunknown({wstrb_in_use, wlast}),
          clk_i, !rst_ni || disable_sva)

  // Check burst rules (A3.4.1), AxCACHE (A4.4), exclusive restrictions (A7.2.4) and AXI4-Lite
  // omitted-signal defaults (B1.1.1, A9.3)
  `ASSERT(AwRequestLegal_A,
          (awvalid === 1'b1 && !$isunknown({awaddr_in_use, awlen, awsize, awburst, awlock,
                                            awcache})) |->
            request_is_legal(awaddr_in_use, awlen, awsize, awburst, awlock, awcache),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(ArRequestLegal_A,
          (arvalid === 1'b1 && !$isunknown({araddr_in_use, arlen, arsize, arburst, arlock,
                                            arcache})) |->
            request_is_legal(araddr_in_use, arlen, arsize, arburst, arlock, arcache),
          clk_i, !rst_ni || disable_sva)

  // Every AXI4-Lite write beat is the last of its burst (B1.1.1)
  `ASSERT(LiteWLast_A, (is_lite && wvalid === 1'b1) |-> wlast === 1'b1,
          clk_i, !rst_ni || disable_sva)

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Write data against its write request
  //
  // Pair W bursts with AW in order (A5.2.2). Buffer W beats that precede AW (A3.3.1), and discard
  // state on reset (A3.1.2).
  ////////////////////////////////////////////////////////////////////////////////////////////////

  typedef struct {
    logic [AxiMaxAddrWidth-1:0] addr;
    logic [AxiLenWidth-1:0]     len;
    logic [AxiSizeWidth-1:0]    size;
    logic [AxiBurstWidth-1:0]   burst;
  } req_t;

  // Write requests whose W burst has not finished, in AW order
  req_t                       aw_q[$];
  // The strobes and WLAST of W beats whose AW handshake has not happened yet, in order
  logic [AxiMaxStrbWidth-1:0] early_strb_q[$];
  logic                       early_last_q[$];
  // Beats so far in the W burst in progress
  int unsigned                w_beats;

  // Check strobes against beat lanes (A3.4.4) and WLAST only on the final beat (A3.2.2)
  function automatic void check_w_beat(req_t req, int unsigned n, logic [AxiMaxStrbWidth-1:0] strb,
                                       logic last);
    logic [AxiMaxStrbWidth-1:0] lanes = beat_lanes(req.addr, req.len, req.size, req.burst, n);

    `ASSERT_I(WStrbOnBeatLanes_A, (strb & ~lanes) == '0)
    `ASSERT_I(WLastOnLastBeat_A, last === (n == int'(req.len)))
  endfunction : check_w_beat

  always @(posedge clk_i or negedge rst_ni) begin
    if (rst_ni !== 1'b1) begin
      aw_q.delete();
      early_strb_q.delete();
      early_last_q.delete();
      w_beats = 0;
    end else if (!disable_sva) begin
      // Apply W to the oldest unfinished write whose AW has handshaken
      if (wvalid === 1'b1 && wready === 1'b1) begin
        if (aw_q.size() > 0 && early_strb_q.size() == 0) begin
          check_w_beat(aw_q[0], w_beats, wstrb_in_use, wlast);
        end else begin
          early_strb_q.push_back(wstrb_in_use);
          early_last_q.push_back(wlast);
        end
        w_beats++;
        if (wlast === 1'b1) begin
          if (aw_q.size() > 0 && early_strb_q.size() == 0) begin
            void'(aw_q.pop_front());
          end
          w_beats = 0;
        end
      end

      if (awvalid === 1'b1 && awready === 1'b1) begin
        req_t req;

        req.addr  = awaddr_in_use;
        req.len   = awlen;
        req.size  = awsize;
        req.burst = awburst;
        aw_q.push_back(req);
        while (aw_q.size() > 0 && early_strb_q.size() > 0) begin
          int unsigned n;
          logic        last;

          n = 0;
          do begin
            last = early_last_q.pop_front();
            check_w_beat(aw_q[0], n, early_strb_q.pop_front(), last);
            n++;
          end while (last !== 1'b1 && early_strb_q.size() > 0);
          if (last === 1'b1) begin
            void'(aw_q.pop_front());
          end else begin
            w_beats = n;
          end
        end
      end

      // Check a W beat while it waits for WREADY too, so a beat that reset cuts off is checked
      if (wvalid === 1'b1 && wready !== 1'b1 && aw_q.size() > 0 && early_strb_q.size() == 0) begin
        check_w_beat(aw_q[0], w_beats, wstrb_in_use, wlast);
      end
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Exclusive accesses
  //
  // An exclusive write cannot start until its read completes (A7.2.2). Reject it while a same-ID
  // exclusive read remains between AR and last R. Track reads in same-ID response order (A5.1). A
  // write starts with its AW, or with its first W beat if that comes before the AW (A3.3.1).
  ////////////////////////////////////////////////////////////////////////////////////////////////

  typedef bit [AxiMaxIdWidth-1:0] id_t;

  // Exclusive flags for outstanding reads per ID, oldest first
  bit reads_open[id_t][$];

  // Whether AWVALID was waiting for AWREADY at the previous edge
  bit aw_waiting;

  // AW handshakes and W bursts started since reset, and whether a W burst is under way
  int unsigned aw_count, w_count;
  bit          w_started;

  // For each W burst, numbered since reset, that started before its AW: the IDs with an exclusive
  // read open then
  bit early_w_excl[int unsigned][id_t];

  // Return whether an exclusive read with this ID is open
  function automatic bit excl_read_open(id_t id);
    if (!reads_open.exists(id)) begin
      return 1'b0;
    end
    foreach (reads_open[id][i]) begin
      if (reads_open[id][i]) begin
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction : excl_read_open

  always @(posedge clk_i or negedge rst_ni) begin
    if (rst_ni !== 1'b1) begin
      reads_open.delete();
      aw_waiting = 1'b0;
      aw_count   = 0;
      w_count    = 0;
      w_started  = 1'b0;
      early_w_excl.delete();
    end else if (!disable_sva) begin
      // A read whose AR handshakes at this edge has started, so it is open for the checks below
      if (arvalid === 1'b1 && arready === 1'b1) begin
        reads_open[arid_in_use].push_back(arlock === 1'b1);
      end

      // A W burst that starts before its AW is presented starts its write, so record the open
      // exclusive reads for the AW to be checked against
      if (wvalid === 1'b1 && !w_started) begin
        if (w_count > aw_count || (w_count == aw_count && awvalid !== 1'b1)) begin
          foreach (reads_open[id]) begin
            if (excl_read_open(id)) begin
              early_w_excl[w_count][id] = 1'b1;
            end
          end
        end
        w_started = 1'b1;
        w_count++;
      end

      // Check a new exclusive AW against reads open before this edge's R handshakes, and against
      // those open when its W data started
      if (awvalid === 1'b1 && awlock === 1'b1 && !aw_waiting) begin
        `ASSERT_I(ExclWriteAfterExclRead_A,
                  !excl_read_open(awid_in_use) &&
                  !(early_w_excl.exists(aw_count) && early_w_excl[aw_count].exists(awid_in_use)))
      end
      if (rvalid === 1'b1 && rready === 1'b1 && rlast === 1'b1 &&
          reads_open.exists(rid_in_use) && reads_open[rid_in_use].size() > 0) begin
        void'(reads_open[rid_in_use].pop_front());
      end
      if (awvalid === 1'b1 && awready === 1'b1) begin
        early_w_excl.delete(aw_count);
        aw_count++;
      end
      if (wvalid === 1'b1 && wready === 1'b1 && wlast === 1'b1) begin
        w_started = 1'b0;
      end
      aw_waiting = (awvalid === 1'b1 && awready !== 1'b1);
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Region identifiers
  //
  // AxREGION is constant within each 4KB address space (A8.2.1). Remember the first value per page
  // and channel, and preserve this system region map across reset.
  ////////////////////////////////////////////////////////////////////////////////////////////////

  typedef bit [AxiMaxAddrWidth-13:0] page_t;

  // The AxREGION of each 4KB page that a request has used, per channel
  logic [AxiRegionWidth-1:0] aw_page_region[page_t];
  logic [AxiRegionWidth-1:0] ar_page_region[page_t];

  always @(posedge clk_i) begin
    if (rst_ni === 1'b1 && !disable_sva) begin
      page_t page;

      if (awvalid === 1'b1 && awready === 1'b1 && !$isunknown({awaddr_in_use, awregion})) begin
        page = page_t'(awaddr_in_use >> 12);
        if (aw_page_region.exists(page)) begin
          `ASSERT_I(AwRegionPerPage_A, awregion === aw_page_region[page])
        end else begin
          aw_page_region[page] = awregion;
        end
      end
      if (arvalid === 1'b1 && arready === 1'b1 && !$isunknown({araddr_in_use, arregion})) begin
        page = page_t'(araddr_in_use >> 12);
        if (ar_page_region.exists(page)) begin
          `ASSERT_I(ArRegionPerPage_A, arregion === ar_page_region[page])
        end else begin
          ar_page_region[page] = arregion;
        end
      end
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Bounds on the manager accepting responses
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // The edges before this one at which BVALID and RVALID waited for READY
  int unsigned b_wait, r_wait;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      b_wait <= 0;
      r_wait <= 0;
    end else begin
      b_wait <= (bvalid === 1'b1 && bready !== 1'b1) ? b_wait + 1 : 0;
      r_wait <= (rvalid === 1'b1 && rready !== 1'b1) ? r_wait + 1 : 0;
    end
  end

  // AXI sets no timeout, but with max_ready_wait set, VALID may wait for READY at most that many
  // edges
  `ASSERT(BReadyWaitBounded_A,
          (max_ready_wait != 0 && bvalid === 1'b1 && bready !== 1'b1) |-> b_wait < max_ready_wait,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(RReadyWaitBounded_A,
          (max_ready_wait != 0 && rvalid === 1'b1 && rready !== 1'b1) |-> r_wait < max_ready_wait,
          clk_i, !rst_ni || disable_sva)

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Output timing
  //
  // Manager outputs change after rising ACLK edges (A3.1.1), and ARESETn rises at one (A3.1.2).
  // Allow changes in the edge's time step or up to max_output_delay_ps later for delayed models.
  // Reset release uses max_reset_release_delay_ps. Ignore changes during reset. Combinatorial paths
  // from inputs to outputs are not visible.
  ////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ChgAw    = 0;
  localparam int ChgW     = 1;
  localparam int ChgAr    = 2;
  localparam int ChgReady = 3;
  localparam int ChgRst   = 4;

  // WDATA on the configured data lanes
  logic [AxiMaxDataWidth-1:0] wdata_on_bus;
  assign wdata_on_bus = wdata & ((AxiMaxDataWidth'(1) << data_width) - 1);

  // Track the last rising edge and the first late change per signal group. A change at the next
  // edge belongs to that edge's time step.
  realtime last_edge;
  bit      seen_edge;
  realtime late_at[5];
  bit      is_late[5];

  function automatic void note_change(int grp, int unsigned max_ps);
    if (seen_edge && rst_ni === 1'b1 && !disable_sva && !is_late[grp] &&
        $rtoi(($realtime - last_edge) / 1ps + 0.5) > max_ps) begin
      late_at[grp] = $realtime;
      is_late[grp] = 1'b1;
    end
  endfunction : note_change

  function automatic bit change_was_late(int grp);
    return is_late[grp] && late_at[grp] != $realtime;
  endfunction : change_was_late

  always @(awvalid, awid_in_use, awaddr_in_use, awregion, awlen, awsize, awburst, awlock, awcache,
           awprot, awqos, awuser_in_use) begin
    note_change(ChgAw, max_output_delay_ps);
  end
  always @(wvalid, wdata_on_bus, wstrb_in_use, wlast, wuser_in_use) begin
    note_change(ChgW, max_output_delay_ps);
  end
  always @(arvalid, arid_in_use, araddr_in_use, arregion, arlen, arsize, arburst, arlock, arcache,
           arprot, arqos, aruser_in_use) begin
    note_change(ChgAr, max_output_delay_ps);
  end
  always @(bready, rready) begin
    note_change(ChgReady, max_output_delay_ps);
  end
  always @(posedge rst_ni) begin
    note_change(ChgRst, max_reset_release_delay_ps);
  end

  always @(posedge clk_i) begin
    `ASSERT_I(AwChangeAfterEdge_A, !change_was_late(ChgAw))
    `ASSERT_I(WChangeAfterEdge_A, !change_was_late(ChgW))
    `ASSERT_I(ArChangeAfterEdge_A, !change_was_late(ChgAr))
    `ASSERT_I(MgrReadyChangeAfterEdge_A, !change_was_late(ChgReady))
    `ASSERT_I(ResetReleaseOnEdge_A, !change_was_late(ChgRst))
    is_late   = '{default: 1'b0};
    last_edge = $realtime;
    seen_edge = 1'b1;
  end

endinterface : axi_mgr_protocol_sva_if
