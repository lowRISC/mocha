// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Assertions for axi_sram, bound into the DUT by the block tb. They cover the verification plan's
// assertion items; the DUT's own output-known checks live in the RTL.

`include "prim_assert.sv"

module axi_sram_assert (
  input logic                           clk_i,
  input logic                           rst_ni,

  // The DUT's AXI device port.
  input top_pkg::axi_dev_req_t          axi_req_i,
  input top_pkg::axi_dev_resp_t         axi_resp_o,

  // The DUT's memory-side request, for the tag write path.
  input logic                           sram_req,
  input logic                           sram_we_d,
  input logic [top_pkg::AxiDataWidth/8-1:0]
                                        sram_be,
  input logic                           sram_cheri_w_tag
);

  // The tag layout assumes an 8-byte bus word and a 16-byte capability, so two words per tag bit.
  `ASSERT_INIT(GeometryMatchesSpec_A,
               top_pkg::AxiDataWidth == 64 && top_pkg::CapSizeBits == 128)

  // The address map must reserve the 128 KiB the SRAM is specified to hold.
  `ASSERT_INIT(SramSizeMatchesSpec_A, top_pkg::SRAMLength == 128 * 1024)

  // A partially strobed write cannot carry a capability, so it must not set the tag (A3.4.4).
  `ASSERT(TagSetNeedsFullStrobe_A,
          sram_req && sram_we_d && sram_cheri_w_tag |-> sram_be == '1,
          clk_i, !rst_ni)

  // Last byte address of an INCR burst, from its aligned start (A4.1.3).
  function automatic logic [top_pkg::AxiAddrWidth-1:0] incr_burst_last_byte(
      logic [top_pkg::AxiAddrWidth-1:0] addr,
      logic [                      7:0] len,
      logic [                      2:0] size);
    logic [top_pkg::AxiAddrWidth-1:0] beat_bytes = top_pkg::AxiAddrWidth'(1) << size;
    logic [top_pkg::AxiAddrWidth-1:0] aligned    = addr & ~(beat_bytes - 1);
    return aligned + ((top_pkg::AxiAddrWidth'(len) + 1) << size) - 1;
  endfunction

  // A burst must not cross a 4KB boundary (A4.1.2). The SRAM is one contiguous mapped region, so a
  // crossing burst would also take its later beats outside the range the map gives it. Only INCR
  // is checked: a FIXED burst reuses one address and a WRAP burst stays inside its aligned block,
  // and axi_to_detailed_mem rejects a multi-beat burst of either kind outright.
  `ASSERT(AwNo4kbCrossing_A,
          axi_req_i.aw_valid && axi_resp_o.aw_ready && axi_req_i.aw.burst == 2'b01 |->
          (axi_req_i.aw.addr >> 12) ==
          (incr_burst_last_byte(axi_req_i.aw.addr, axi_req_i.aw.len, axi_req_i.aw.size) >> 12),
          clk_i, !rst_ni)

  `ASSERT(ArNo4kbCrossing_A,
          axi_req_i.ar_valid && axi_resp_o.ar_ready && axi_req_i.ar.burst == 2'b01 |->
          (axi_req_i.ar.addr >> 12) ==
          (incr_burst_last_byte(axi_req_i.ar.addr, axi_req_i.ar.len, axi_req_i.ar.size) >> 12),
          clk_i, !rst_ni)

  // A request is answered within a bounded window, measured from where the memory has all it
  // needs -- the last write beat, or the read request -- so the bound does not depend on how the
  // manager paces the channels. Later beats of a read burst are paced by RREADY, so only the first
  // is bounded.
  localparam int unsigned RespMaxCycles = 32;

  `ASSERT(BValidBounded_A,
          axi_req_i.w_valid && axi_resp_o.w_ready && axi_req_i.w.last |=>
          ##[0:RespMaxCycles] axi_resp_o.b_valid,
          clk_i, !rst_ni)

  `ASSERT(RValidBounded_A,
          axi_req_i.ar_valid && axi_resp_o.ar_ready |=>
          ##[0:RespMaxCycles] axi_resp_o.r_valid,
          clk_i, !rst_ni)

  // Track the read burst in flight, to check a capability read's two RUSER beats against each
  // other. The memory answers reads in request order and never interleaves beats of different
  // bursts, so one burst's beats always arrive together.
  logic        r_beat;              // an R beat is accepted this cycle
  logic        tag_write;           // the tag memory is written this cycle
  logic        r_in_burst;          // a burst is open: its first beat went out, its last has not
  logic        r_first_user;        // RUSER of the open burst's first beat
  int unsigned r_beat_count;        // beats of the open burst accepted so far
  logic        r_tag_write_seen;    // a tag write landed since the open burst's first beat

  assign r_beat    = axi_resp_o.r_valid && axi_req_i.r_ready;
  assign tag_write = sram_req && sram_we_d;

  // Attributes of the AR governing the beats on the bus. The memory accepts one read burst at a
  // time, so a single set of registers tracks it.
  logic [7:0] ar_len_q;
  logic [2:0] ar_size_q;
  logic [3:0] ar_alo_q;             // the request's addr[3:0]

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      ar_len_q  <= '0;
      ar_size_q <= '0;
      ar_alo_q  <= '0;
    end else if (axi_req_i.ar_valid && axi_resp_o.ar_ready) begin
      ar_len_q  <= axi_req_i.ar.len;
      ar_size_q <= axi_req_i.ar.size;
      ar_alo_q  <= axi_req_i.ar.addr[3:0];
    end
  end

  // A capability read is two 8-byte beats from a 16-byte boundary. Any other read must come back
  // with the tag cleared, so no read that starts part way into a slot can return a capability
  // assembled out of two halves.
  `ASSERT(NonCapReadHasNoTag_A,
          r_beat && !(ar_len_q == 8'd1 && ar_size_q == 3'd3 && ar_alo_q == 4'd0) |->
          axi_resp_o.r.user[0] == 1'b0,
          clk_i, !rst_ni)

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      r_in_burst       <= 1'b0;
      r_first_user     <= 1'b0;
      r_beat_count     <= 0;
      r_tag_write_seen <= 1'b0;
    end else if (r_beat) begin
      r_in_burst <= !axi_resp_o.r.last;
      if (!r_in_burst) begin
        r_first_user     <= axi_resp_o.r.user[0];
        r_beat_count     <= 1;
        r_tag_write_seen <= tag_write;
      end else begin
        r_beat_count     <= r_beat_count + 1;
        r_tag_write_seen <= r_tag_write_seen | tag_write;
      end
    end else if (r_in_burst) begin
      r_tag_write_seen <= r_tag_write_seen | tag_write;
    end
  end

  // A capability read is a two-beat burst and its region owns a single tag bit, so both beats
  // return the same value. Excluded is a tag write landing inside the burst, which the manager has
  // not ordered against the read: the beats are separate memory accesses, so either may see it.
  `ASSERT(CapReadRuserBeatsAgree_A,
          r_beat && axi_resp_o.r.last && r_in_burst && r_beat_count == 1 &&
          !(r_tag_write_seen || tag_write) |-> axi_resp_o.r.user[0] == r_first_user,
          clk_i, !rst_ni)

endmodule
