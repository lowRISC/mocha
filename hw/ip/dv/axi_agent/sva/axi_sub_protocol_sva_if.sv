// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Check AXI Subordinate obligations from AMBA AXI H.c (assertion comments cite the checked
// sections)
`include "prim_assert.sv"

interface axi_sub_protocol_sva_if
  import axi_widths_pkg::*;
(
  input logic                           clk_i,
  input logic                           rst_ni,

  input logic                           awvalid,
  input logic                           awready,
  input logic [AxiMaxIdWidth-1:0]       awid,
  input logic [AxiMaxAddrWidth-1:0]     awaddr,
  input logic [AxiLenWidth-1:0]         awlen,
  input logic [AxiSizeWidth-1:0]        awsize,
  input logic [AxiBurstWidth-1:0]       awburst,
  input logic                           awlock,

  input logic                           wvalid,
  input logic                           wready,
  input logic                           wlast,

  input logic                           bvalid,
  input logic                           bready,
  input logic [AxiMaxIdWidth-1:0]       bid,
  input logic [AxiRespWidth-1:0]        bresp,
  input logic [AxiMaxRespUserWidth-1:0] buser,

  input logic                           arvalid,
  input logic                           arready,
  input logic [AxiMaxIdWidth-1:0]       arid,
  input logic [AxiMaxAddrWidth-1:0]     araddr,
  input logic [AxiLenWidth-1:0]         arlen,
  input logic [AxiSizeWidth-1:0]        arsize,
  input logic [AxiBurstWidth-1:0]       arburst,
  input logic                           arlock,

  input logic                           rvalid,
  input logic                           rready,
  input logic [AxiMaxIdWidth-1:0]       rid,
  input logic [AxiMaxDataWidth-1:0]     rdata,
  input logic [AxiRespWidth-1:0]        rresp,
  input logic                           rlast,
  input logic [AxiMaxRUserWidth-1:0]    ruser,

  // Bus properties from the channel interfaces
  input int unsigned                    id_w_width,
  input int unsigned                    id_r_width,
  input int unsigned                    addr_width,
  input int unsigned                    data_width,
  input int unsigned                    user_data_width,
  input int unsigned                    b_user_resp_width,
  input int unsigned                    r_user_resp_width,
  input bit                             is_lite,

  // Settings from axi_if, which documents them with its set_* functions
  input bit                             disable_sva,
  input int unsigned                    max_ready_wait,
  input int unsigned                    max_output_delay_ps
);

  // Local AxBURST and xRESP encodings keep the checker independent
  localparam logic [1:0] BurstFixed = 2'b00;
  localparam logic [1:0] BurstWrap  = 2'b10;
  localparam logic [1:0] RespOkay   = 2'b00;
  localparam logic [1:0] RespExOkay = 2'b01;

  // Use only configured bits, because higher bits of maximum-width interface signals are undriven
  logic [AxiMaxIdWidth-1:0]       awid_in_use, bid_in_use, arid_in_use, rid_in_use;
  logic [AxiMaxAddrWidth-1:0]     awaddr_in_use, araddr_in_use;
  logic [AxiMaxRespUserWidth-1:0] buser_in_use;
  logic [AxiMaxRUserWidth-1:0]    ruser_in_use;
  assign awid_in_use   = awid & ((AxiMaxIdWidth'(1) << id_w_width) - 1);
  assign bid_in_use    = bid & ((AxiMaxIdWidth'(1) << id_w_width) - 1);
  assign arid_in_use   = arid & ((AxiMaxIdWidth'(1) << id_r_width) - 1);
  assign rid_in_use    = rid & ((AxiMaxIdWidth'(1) << id_r_width) - 1);
  assign awaddr_in_use = awaddr & ((AxiMaxAddrWidth'(1) << addr_width) - 1);
  assign araddr_in_use = araddr & ((AxiMaxAddrWidth'(1) << addr_width) - 1);
  assign buser_in_use  = buser & ((AxiMaxRespUserWidth'(1) << b_user_resp_width) - 1);
  assign ruser_in_use  = ruser & ((AxiMaxRUserWidth'(1) << (user_data_width + r_user_resp_width)) -
                                  1);

  // Return beat n's lanes (A3.4.1, A3.4.2). FIXED reuses the first beat's lanes, and unaligned
  // beats end at their aligned container's end.
  function automatic logic [AxiMaxDataWidth-1:0] beat_data_mask(logic [AxiMaxAddrWidth-1:0] addr,
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
    logic [AxiMaxDataWidth-1:0] mask = '0;

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
      mask[8 * lane +: 8] = 8'hff;
    end
    return mask;
  endfunction : beat_data_mask

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Handshakes on B and R
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // Once VALID is high it stays high until the handshake (A3.2.1)
  `ASSERT(BValidHeld_A, (bvalid === 1'b1 && bready !== 1'b1) |=> bvalid === 1'b1,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(RValidHeld_A, (rvalid === 1'b1 && rready !== 1'b1) |=> rvalid === 1'b1,
          clk_i, !rst_ni || disable_sva)

  // Hold response fields stable until READY (A3.2.1). Check RDATA separately on active beat lanes
  // (A3.4.4).
  `ASSERT(BStable_A,
          (bvalid === 1'b1 && bready !== 1'b1) |=>
            $stable({bid_in_use, bresp, buser_in_use}),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(RStable_A,
          (rvalid === 1'b1 && rready !== 1'b1) |=>
            $stable({rid_in_use, rresp, rlast, ruser_in_use}),
          clk_i, !rst_ni || disable_sva)

  // VALID is low at every edge during reset (A3.1.2)
  `ASSERT(BLowInReset_A, rst_ni === 1'b0 |-> bvalid === 1'b0, clk_i, disable_sva)
  `ASSERT(RLowInReset_A, rst_ni === 1'b0 |-> rvalid === 1'b0, clk_i, disable_sva)

  // Require known VALID outside reset and known AWREADY/WREADY/ARREADY when VALID is high. This is
  // an X-checking convention, beyond H.c. READY with VALID low is irrelevant and may depend on idle
  // payload.
  `ASSERT(SubHandshakeKnown_A,
          !$isunknown({bvalid, rvalid}) && (awvalid !== 1'b1 || !$isunknown(awready)) &&
          (wvalid !== 1'b1 || !$isunknown(wready)) && (arvalid !== 1'b1 || !$isunknown(arready)),
          clk_i, !rst_ni || disable_sva)

  // Require known response control fields while VALID is high, using the same X-checking convention
  `ASSERT(BControlKnown_A, bvalid === 1'b1 |-> !$isunknown({bid_in_use, bresp}),
          clk_i, !rst_ni || disable_sva)
  `ASSERT(RControlKnown_A, rvalid === 1'b1 |-> !$isunknown({rid_in_use, rresp, rlast}),
          clk_i, !rst_ni || disable_sva)

  // Every AXI4-Lite read beat is the last of its burst, and AXI4-Lite has no EXOKAY (B1.1.1)
  `ASSERT(LiteRLast_A, (is_lite && rvalid === 1'b1) |-> rlast === 1'b1,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(LiteNoBExOkay_A, (is_lite && bvalid === 1'b1) |-> bresp !== RespExOkay,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(LiteNoRExOkay_A, (is_lite && rvalid === 1'b1) |-> rresp !== RespExOkay,
          clk_i, !rst_ni || disable_sva)

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Responses against the requests they answer
  //
  // Writes become answerable after AW and the final W handshake, and reads after AR (A3.3.1). Pair
  // W bursts in AW order (A5.2.2), and responses with each ID's oldest request (A5.1). Discard
  // state on reset (A3.1.2).
  ////////////////////////////////////////////////////////////////////////////////////////////////

  typedef bit [AxiMaxIdWidth-1:0] id_t;

  typedef struct {
    id_t                        id;
    logic [AxiMaxAddrWidth-1:0] addr;
    logic [AxiLenWidth-1:0]     len;
    logic [AxiSizeWidth-1:0]    size;
    logic [AxiBurstWidth-1:0]   burst;
    logic                       lock;
  } req_t;

  // AW requests waiting for W data, in order, and W bursts completed before AW
  req_t        aw_wait_w_q[$];
  int unsigned w_bursts_early;

  // Per ID, the writes that can be answered, and the reads waiting for their last R beat, in order
  req_t        b_wait_q[id_t][$];
  req_t        r_wait_q[id_t][$];

  // Per ID: oldest read's beat count and whether OKAY or EXOKAY appeared
  int unsigned r_beats[id_t];
  bit          r_saw_okay[id_t];
  bit          r_saw_exokay[id_t];

  // Whether BVALID or RVALID was waiting for READY at the previous edge
  bit b_waiting, r_waiting;

  // Previous stalled RDATA and its active-lane bit mask
  logic [AxiMaxDataWidth-1:0] r_wait_data, r_wait_mask;

  // Return the next R beat's active data bits for this ID, or all bus bits if no read is
  // outstanding
  function automatic logic [AxiMaxDataWidth-1:0] next_r_beat_mask(id_t id);
    req_t req;

    if (!(r_wait_q.exists(id) && r_wait_q[id].size() > 0)) begin
      return (AxiMaxDataWidth'(1) << data_width) - 1;
    end
    req = r_wait_q[id][0];
    return beat_data_mask(req.addr, req.len, req.size, req.burst, r_beats[id]);
  endfunction : next_r_beat_mask

  // Only exclusive writes may get EXOKAY (A3.4.5, A7.2.5)
  function automatic void check_b_resp(req_t req, logic [AxiRespWidth-1:0] resp);
    `ASSERT_I(BExOkayOnlyForExclusive_A, !(resp[1:0] == RespExOkay && !req.lock))
  endfunction : check_b_resp

  // Check an R beat for the oldest read with this ID: RLAST only on its final beat (A3.2.2), EXOKAY
  // only for an exclusive read, and no mix of OKAY and EXOKAY in one read (A3.4.5, A7.2.5)
  function automatic void check_r_beat(id_t id, logic [AxiRespWidth-1:0] resp, logic last);
    req_t        req = r_wait_q[id][0];
    int unsigned n   = r_beats[id];

    `ASSERT_I(RExOkayOnlyForExclusive_A, !(resp[1:0] == RespExOkay && !req.lock))
    `ASSERT_I(RLastOnLastBeat_A, last === (n == int'(req.len)))
    `ASSERT_I(RNoOkayExOkayMix_A, !(resp[1:0] == RespExOkay && r_saw_okay[id]) &&
                                  !(resp[1:0] == RespOkay && r_saw_exokay[id]))
  endfunction : check_r_beat

  // B answers the oldest answerable write with its ID
  function automatic void on_b_handshake(id_t id, logic [AxiRespWidth-1:0] resp);
    if (!(b_wait_q.exists(id) && b_wait_q[id].size() > 0)) begin
      return;
    end
    check_b_resp(b_wait_q[id].pop_front(), resp);
  endfunction : on_b_handshake

  // R answers the oldest same-ID read, with known active-lane data on success
  function automatic void on_r_handshake(id_t id, logic [AxiRespWidth-1:0] resp, logic last,
                                         logic [AxiMaxDataWidth-1:0] data);
    req_t        req;
    int unsigned n;

    if (!(r_wait_q.exists(id) && r_wait_q[id].size() > 0)) begin
      return;
    end
    req = r_wait_q[id][0];
    n   = r_beats[id];

    check_r_beat(id, resp, last);
    `ASSERT_I(RDataKnownOnBeatLanes_A,
              !(resp[1:0] inside {RespOkay, RespExOkay}) ||
              !$isunknown(data & beat_data_mask(req.addr, req.len, req.size, req.burst, n)))

    r_saw_okay[id]   |= (resp[1:0] == RespOkay);
    r_saw_exokay[id] |= (resp[1:0] == RespExOkay);
    r_beats[id]++;
    if (last === 1'b1 || r_beats[id] > int'(req.len)) begin
      void'(r_wait_q[id].pop_front());
      r_beats[id]      = 0;
      r_saw_okay[id]   = 1'b0;
      r_saw_exokay[id] = 1'b0;
    end
  endfunction : on_r_handshake

  always @(posedge clk_i or negedge rst_ni) begin
    if (rst_ni !== 1'b1) begin
      aw_wait_w_q.delete();
      w_bursts_early = 0;
      b_wait_q.delete();
      r_wait_q.delete();
      r_beats.delete();
      r_saw_okay.delete();
      r_saw_exokay.delete();
      b_waiting = 1'b0;
      r_waiting = 1'b0;
    end else if (!disable_sva) begin
      // RDATA stays stable on the lanes of its beat while RVALID waits for RREADY (A3.2.1, A3.4.4)
      if (r_waiting) begin
        `ASSERT_I(RDataStable_A, (rdata & r_wait_mask) === (r_wait_data & r_wait_mask))
      end

      // Responses require requests made answerable at earlier edges, so check responses before
      // adding this edge's requests (A3.3.1)
      if (bvalid === 1'b1 && !b_waiting) begin
        `ASSERT_I(BOnlyForAnswerableWrite_A,
                  b_wait_q.exists(bid_in_use) && b_wait_q[bid_in_use].size() > 0)
      end
      if (rvalid === 1'b1 && !r_waiting) begin
        `ASSERT_I(ROnlyForOutstandingRead_A,
                  r_wait_q.exists(rid_in_use) && r_wait_q[rid_in_use].size() > 0)
      end

      if (bvalid === 1'b1 && bready === 1'b1) begin
        on_b_handshake(bid_in_use, bresp);
      end
      if (rvalid === 1'b1 && rready === 1'b1) begin
        on_r_handshake(rid_in_use, rresp, rlast, rdata);
      end

      // Check a response waiting for READY too, so one that reset cuts off is checked
      if (bvalid === 1'b1 && bready !== 1'b1 && b_wait_q.exists(bid_in_use) &&
          b_wait_q[bid_in_use].size() > 0) begin
        check_b_resp(b_wait_q[bid_in_use][0], bresp);
      end
      if (rvalid === 1'b1 && rready !== 1'b1 && r_wait_q.exists(rid_in_use) &&
          r_wait_q[rid_in_use].size() > 0) begin
        check_r_beat(rid_in_use, rresp, rlast);
      end

      // Finish the oldest write waiting for W, including a burst whose AW has not arrived
      if (wvalid === 1'b1 && wready === 1'b1 && wlast === 1'b1) begin
        if (aw_wait_w_q.size() > 0) begin
          req_t req;

          req = aw_wait_w_q.pop_front();
          b_wait_q[req.id].push_back(req);
        end else begin
          w_bursts_early++;
        end
      end

      if (awvalid === 1'b1 && awready === 1'b1) begin
        req_t req;

        req.id    = awid_in_use;
        req.addr  = awaddr_in_use;
        req.len   = awlen;
        req.size  = awsize;
        req.burst = awburst;
        req.lock  = awlock;
        if (w_bursts_early > 0) begin
          w_bursts_early--;
          b_wait_q[req.id].push_back(req);
        end else begin
          aw_wait_w_q.push_back(req);
        end
      end

      if (arvalid === 1'b1 && arready === 1'b1) begin
        req_t req;

        req.id    = arid_in_use;
        req.addr  = araddr_in_use;
        req.len   = arlen;
        req.size  = arsize;
        req.burst = arburst;
        req.lock  = arlock;
        r_wait_q[req.id].push_back(req);
      end

      b_waiting = (bvalid === 1'b1 && bready !== 1'b1);
      r_waiting = (rvalid === 1'b1 && rready !== 1'b1);
      if (r_waiting) begin
        r_wait_data = rdata;
        r_wait_mask = next_r_beat_mask(rid_in_use);
      end
    end
  end

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Bounds on the subordinate accepting requests
  ////////////////////////////////////////////////////////////////////////////////////////////////

  // The edges before this one at which AWVALID, WVALID and ARVALID waited for READY
  int unsigned aw_wait, w_wait, ar_wait;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_wait <= 0;
      w_wait  <= 0;
      ar_wait <= 0;
    end else begin
      aw_wait <= (awvalid === 1'b1 && awready !== 1'b1) ? aw_wait + 1 : 0;
      w_wait  <= (wvalid === 1'b1 && wready !== 1'b1) ? w_wait + 1 : 0;
      ar_wait <= (arvalid === 1'b1 && arready !== 1'b1) ? ar_wait + 1 : 0;
    end
  end

  // AXI sets no timeout, but with max_ready_wait set, VALID may wait for READY at most that many
  // edges
  `ASSERT(AwReadyWaitBounded_A,
          (max_ready_wait != 0 && awvalid === 1'b1 && awready !== 1'b1) |->
          aw_wait < max_ready_wait,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(WReadyWaitBounded_A,
          (max_ready_wait != 0 && wvalid === 1'b1 && wready !== 1'b1) |-> w_wait < max_ready_wait,
          clk_i, !rst_ni || disable_sva)
  `ASSERT(ArReadyWaitBounded_A,
          (max_ready_wait != 0 && arvalid === 1'b1 && arready !== 1'b1) |->
          ar_wait < max_ready_wait,
          clk_i, !rst_ni || disable_sva)

  ////////////////////////////////////////////////////////////////////////////////////////////////
  // Output timing
  //
  // Subordinate outputs change after rising ACLK edges (A3.1.1). Allow changes in the edge's time
  // step or up to max_output_delay_ps later for delayed models. Ignore changes during reset. The
  // manager checks ARESETn release. Combinatorial paths from inputs to outputs are not visible.
  ////////////////////////////////////////////////////////////////////////////////////////////////

  localparam int ChgReady = 0;
  localparam int ChgB     = 1;
  localparam int ChgR     = 2;

  // RDATA on the configured data lanes
  logic [AxiMaxDataWidth-1:0] rdata_on_bus;
  assign rdata_on_bus = rdata & ((AxiMaxDataWidth'(1) << data_width) - 1);

  // Track the last rising edge and the first late change per signal group. A change at the next
  // edge belongs to that edge's time step.
  realtime last_edge;
  bit      seen_edge;
  realtime late_at[3];
  bit      is_late[3];

  function automatic void note_change(int grp);
    if (seen_edge && rst_ni === 1'b1 && !disable_sva && !is_late[grp] &&
        $rtoi(($realtime - last_edge) / 1ps + 0.5) > max_output_delay_ps) begin
      late_at[grp] = $realtime;
      is_late[grp] = 1'b1;
    end
  endfunction : note_change

  function automatic bit change_was_late(int grp);
    return is_late[grp] && late_at[grp] != $realtime;
  endfunction : change_was_late

  always @(awready, wready, arready) begin
    note_change(ChgReady);
  end
  always @(bvalid, bid_in_use, bresp, buser_in_use) begin
    note_change(ChgB);
  end
  always @(rvalid, rid_in_use, rdata_on_bus, rresp, rlast, ruser_in_use) begin
    note_change(ChgR);
  end

  always @(posedge clk_i) begin
    `ASSERT_I(SubReadyChangeAfterEdge_A, !change_was_late(ChgReady))
    `ASSERT_I(BChangeAfterEdge_A, !change_was_late(ChgB))
    `ASSERT_I(RChangeAfterEdge_A, !change_was_late(ChgR))
    is_late   = '{default: 1'b0};
    last_edge = $realtime;
    seen_edge = 1'b1;
  end

endinterface : axi_sub_protocol_sva_if
