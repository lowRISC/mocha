// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// Functional coverage for axi_sram -- CHERI tag write gating and tag read/ruser.
//
// This is a passive sampler on the SRAM's AXI port. It snoops the AXI
// request/response structs and, because the W and R channels carry no address,
// keeps small AW/AR attribute FIFOs (AXI4 keeps write/read data in request order)
// so each W/R beat can be attributed to its governing request. One write-burst
// sample is taken at WLAST and one read-burst sample at RLAST.
//
// Carries the verification plan's two coverage items:
//   cg_tag_write -- conditions that set, and must not set, a tag
//   cg_tag_read  -- per-beat RUSER returned on reads

module axi_sram_cov (
  input logic                   clk_i,
  input logic                   rst_ni,
  input top_pkg::axi_dev_req_t  axi_req,
  input top_pkg::axi_dev_resp_t axi_resp
);

  localparam int unsigned FifoDepth = 16;

  // Covergroups

  // Tag-write gating. The tag is set only by a *full capability write*: a
  // single 2-beat (awlen==1), 8-byte (awsize==3), 16-byte-aligned burst with full
  // write strobes and wuser=1. The crosses below confirm we exercised that
  // condition and each disqualifying corner (single beat, sub-word, misaligned,
  // partial strobe) with a tag bit asserted.
  covergroup cg_tag_write with function sample(bit [7:0] len, bit [2:0] size,
                                               bit aligned, bit full_strobe,
                                               bit user_any, bit mismatch);
    option.per_instance = 1;

    cp_len: coverpoint len {
      bins single = {0};       // awlen==0 : single beat
      bins cap    = {1};       // awlen==1 : capability-shaped
      bins multi  = {[2:255]}; // longer bursts
    }
    cp_size: coverpoint size {
      bins word    = {3};      // 8-byte beats
      bins subword = {[0:2]};  // narrower
    }
    cp_align: coverpoint aligned {        // governing awaddr[3:0]==0
      bins aligned   = {1};
      bins unaligned = {0};
    }
    cp_strb: coverpoint full_strobe {     // every beat had full WSTRB
      bins full    = {1};
      bins partial = {0};
    }
    cp_user: coverpoint user_any {        // any beat asserted wuser=1
      bins with_tag = {1};
      bins no_tag   = {0};
    }
    cp_mismatch: coverpoint mismatch {    // cap-shaped burst, beats disagree on wuser
      bins match    = {0};
      bins mismatch = {1};
    }

    // Each gating dimension crossed with "tag bit asserted".
    x_len_user   : cross cp_len,   cp_user;   // single/cap/multi x tagged
    x_align_user : cross cp_align, cp_user;   // alignment gating
    x_strb_user  : cross cp_strb,  cp_user;   // partial-strobe gating
    x_size_user  : cross cp_size,  cp_user;   // sub-word gating
  endgroup

  // Tag read / RUSER. One tag bit per 128-bit region drives both beats of a 2-beat
  // capability read equal, so the pair is {00} or {11} unless a tag write lands
  // between the beats. A sub-word read (size<3) of a region returns a cleared tag.
  covergroup cg_tag_read with function sample(bit [7:0] len, bit [2:0] size,
                                              bit u0, bit u1);
    option.per_instance = 1;

    cp_len: coverpoint len {
      bins single = {0};
      bins cap    = {1};
      bins multi  = {[2:255]};
    }
    cp_size: coverpoint size {
      bins word    = {3};
      bins subword = {[0:2]};
    }
    // Per-beat RUSER pair on a 2-beat capability read.
    cp_ruser_pair: coverpoint {u1, u0} iff (len == 8'd1) {
      bins both_clear   = {2'b00};
      bins both_set     = {2'b11};
      // A region owns one tag bit, so the pair is normally equal. It can differ if a tag write
      // lands between the two beats, which the manager has not ordered against the read, so the
      // sample is dropped rather than treated as a bug.
      ignore_bins mixed = {2'b01, 2'b10};
    }
    // Sub-word read returns the tag cleared.
    cp_subword_user: coverpoint u0 iff (size != 3'd3) {
      bins cleared                = {0};
      ignore_bins unexpected_set  = {1};
    }

    x_len_size : cross cp_len, cp_size;   // cap-shaped vs sub-word reads exercised
  endgroup

  cg_tag_write cov_w = new();
  cg_tag_read  cov_r = new();

  // Write side: AW attribute snoop + per-burst W aggregation
  logic [7:0]  aw_len_q  [FifoDepth];
  logic [2:0]  aw_size_q [FifoDepth];
  logic [3:0]  aw_alo_q  [FifoDepth];   // awaddr[3:0]
  int unsigned aw_head, aw_tail, aw_count;

  logic        w_first;                  // next W beat starts a new burst
  logic        w_user0_r;                // wuser of the burst's first beat
  logic        w_full_acc;               // all beats so far were full-strobe
  logic        w_any_acc;                // any beat so far asserted wuser
  logic        w_mism_acc;               // a wuser mismatch seen so far

  // Governing AW attributes for the W beat on the bus this cycle.
  logic [7:0] gw_len;
  logic [2:0] gw_size;
  logic [3:0] gw_alo;
  logic       gw_valid;
  always_comb begin
    if (aw_count != 0) begin
      gw_valid = 1'b1;
      gw_len   = aw_len_q[aw_head];
      gw_size  = aw_size_q[aw_head];
      gw_alo   = aw_alo_q[aw_head];
    end else if (axi_req.aw_valid && axi_resp.aw_ready) begin
      gw_valid = 1'b1;
      gw_len   = axi_req.aw.len;
      gw_size  = axi_req.aw.size;
      gw_alo   = axi_req.aw.addr[3:0];
    end else begin
      gw_valid = 1'b0;
      gw_len   = '0;
      gw_size  = '0;
      gw_alo   = '0;
    end
  end
  wire gw_cap_shaped = gw_valid && (gw_len == 8'd1) && (gw_size == 3'd3) && (gw_alo == 4'd0);
  wire w_beat_full   = &axi_req.w.strb;
  wire w_beat_user   = axi_req.w.user[0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      aw_head <= 0; aw_tail <= 0; aw_count <= 0;
      w_first <= 1'b1; w_user0_r <= 1'b0;
      w_full_acc <= 1'b1; w_any_acc <= 1'b0; w_mism_acc <= 1'b0;
    end else begin
      // AW snoop push
      if (axi_req.aw_valid && axi_resp.aw_ready) begin
        aw_len_q[aw_tail]  <= axi_req.aw.len;
        aw_size_q[aw_tail] <= axi_req.aw.size;
        aw_alo_q[aw_tail]  <= axi_req.aw.addr[3:0];
        aw_tail            <= (aw_tail + 1) % FifoDepth;
      end

      // W beat: aggregate; on the last beat, sample the burst and pop the AW.
      if (axi_req.w_valid && axi_resp.w_ready) begin
        if (axi_req.w.last) begin
          cov_w.sample(gw_len, gw_size, (gw_alo == 4'd0),
                       w_first ? w_beat_full : (w_full_acc & w_beat_full),
                       w_first ? w_beat_user : (w_any_acc  | w_beat_user),
                       w_first ? 1'b0
                               : (w_mism_acc | (gw_cap_shaped & (w_beat_user != w_user0_r))));
          aw_head    <= (aw_head + 1) % FifoDepth;
          w_first    <= 1'b1;
          w_user0_r  <= 1'b0;
          w_full_acc <= 1'b1;
          w_any_acc  <= 1'b0;
          w_mism_acc <= 1'b0;
        end else begin
          w_first    <= 1'b0;
          w_user0_r  <= w_first ? w_beat_user : w_user0_r;
          w_full_acc <= w_first ? w_beat_full : (w_full_acc & w_beat_full);
          w_any_acc  <= w_first ? w_beat_user : (w_any_acc  | w_beat_user);
          w_mism_acc <= w_first ? 1'b0
                                : (w_mism_acc | (gw_cap_shaped & (w_beat_user != w_user0_r)));
        end
      end

      aw_count <= aw_count
                + ((axi_req.aw_valid && axi_resp.aw_ready) ? 1 : 0)
                - ((axi_req.w_valid && axi_resp.w_ready && axi_req.w.last) ? 1 : 0);
    end
  end

  // Read side: AR attribute snoop + per-burst RUSER capture
  logic [7:0]  ar_len_q  [FifoDepth];
  logic [2:0]  ar_size_q [FifoDepth];
  int unsigned ar_head, ar_tail, ar_count;

  logic        r_first;                  // next R beat starts a new burst
  logic        r_user0_r;                // ruser of the burst's first beat

  logic [7:0] gr_len;
  logic [2:0] gr_size;
  logic       gr_valid;
  always_comb begin
    if (ar_count != 0) begin
      gr_valid = 1'b1;
      gr_len   = ar_len_q[ar_head];
      gr_size  = ar_size_q[ar_head];
    end else if (axi_req.ar_valid && axi_resp.ar_ready) begin
      gr_valid = 1'b1;
      gr_len   = axi_req.ar.len;
      gr_size  = axi_req.ar.size;
    end else begin
      gr_valid = 1'b0;
      gr_len   = '0;
      gr_size  = '0;
    end
  end
  wire r_beat_user = axi_resp.r.user[0];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ar_head <= 0; ar_tail <= 0; ar_count <= 0;
      r_first <= 1'b1; r_user0_r <= 1'b0;
    end else begin
      // AR snoop push
      if (axi_req.ar_valid && axi_resp.ar_ready) begin
        ar_len_q[ar_tail]  <= axi_req.ar.len;
        ar_size_q[ar_tail] <= axi_req.ar.size;
        ar_tail            <= (ar_tail + 1) % FifoDepth;
      end

      // R beat: capture first/last RUSER; on the last beat, sample and pop the AR.
      if (axi_resp.r_valid && axi_req.r_ready) begin
        if (axi_resp.r.last) begin
          cov_r.sample(gr_len, gr_size,
                       r_first ? r_beat_user : r_user0_r,  // first-beat ruser
                       r_beat_user);                       // last-beat ruser
          ar_head   <= (ar_head + 1) % FifoDepth;
          r_first   <= 1'b1;
          r_user0_r <= 1'b0;
        end else begin
          r_first   <= 1'b0;
          r_user0_r <= r_first ? r_beat_user : r_user0_r;
        end
      end

      ar_count <= ar_count
                + ((axi_req.ar_valid && axi_resp.ar_ready) ? 1 : 0)
                - ((axi_resp.r_valid && axi_req.r_ready && axi_resp.r.last) ? 1 : 0);
    end
  end

  // Per-run readout, so one run shows what it covered on its own.
  final begin
    $display("[axi_sram_cov] cg_tag_write coverage = %0.2f%%", cov_w.get_coverage());
    $display("[axi_sram_cov] cg_tag_read  coverage = %0.2f%%", cov_r.get_coverage());
  end

endmodule
