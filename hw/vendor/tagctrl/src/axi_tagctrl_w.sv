// Copyright 2023 Bruno Sá and ZeroDay Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   29.11.2023

`include "common_cells/registers.svh"

/// [TODO] Description here

module axi_tagctrl_w #(
    /// Tag Controller parameters configuration struct. This is passed down from
    /// [`axi_tag_ctrl_top`](module.axi_tag_ctrl_top
    parameter axi_tagctrl_pkg::tagctrl_cfg_t Cfg = axi_tagctrl_pkg::tagctrl_cfg_t'{default: '0},
    /// Tag Controller descriptor type definition.
    parameter type desc_t = logic,
    /// Tag Cache write payload definition.
    parameter type tagc_oup_t = logic,
    /// AXI slave port W channel struct definition.
    parameter type w_chan_t = logic,
    /// AXI slave port B channel struct definition.
    parameter type b_chan_t = logic
) (
    /// Clock, positive edge triggered.
    input logic clk_i,
    /// Asynchronous reset, active low.
    input logic rst_ni,
    /// Testmode enable, active high.
    input logic test_i,
    /// Input descriptor payload.
    input desc_t tagctrl_desc_i,
    /// Input descriptor is valid.
    input logic tagctrl_desc_valid_i,
    /// Unit is ready to accept a new descriptor.
    output logic tagctrl_desc_ready_o,
    /// AXI slave port W channel payload input.
    input w_chan_t w_chan_slv_i,
    /// AXI slave port W beat is valid.
    input logic w_chan_slv_valid_i,
    /// AXI slave port W beat is ready.
    output logic w_chan_slv_ready_o,
    /// AXI slave port B channel payload output.
    output b_chan_t b_chan_slv_o,
    /// AXI B beat is valid.
    output logic b_chan_slv_valid_o,
    /// AXI B Beat is ready.
    input logic b_chan_slv_ready_i,
    /// Tag Cache write payload.
    output tagc_oup_t tagc_oup_o,
    /// Tag Cache write payload is valid.
    output logic tagc_oup_valid_o,
    /// Tag Cache is ready.
    input logic tagc_oup_ready_i,
    /// Tag Cache write response payload.
    input b_chan_t tagc_resp_i,
    /// Tag Cache write payload is valid.
    input logic tagc_resp_valid_i,
    /// Tag Cache is ready.
    output logic tagc_resp_ready_o,
    /// AXI W master channel payload.
    output w_chan_t w_chan_mst_o,
    /// AXI W master channel is valid.
    output logic w_chan_mst_valid_o,
    /// AXI W master channel is ready.
    input logic w_chan_mst_ready_i,
    /// AXI B master channel payload.
    input b_chan_t b_chan_mst_i,
    /// AXI B master channel is valid.
    input logic b_chan_mst_valid_i,
    /// AXI B master channel is ready.
    output logic b_chan_mst_ready_o
);
  tagc_oup_t tag_fifo_indata;
  localparam int unsigned TagFlitBits = $bits(tag_fifo_indata.data);
  typedef logic [TagFlitBits-1:0] axi_data_t;
  typedef logic [Cfg.AxiAddrWidth-1:0] axi_addr_t;

  // This module is pipelined, but expects in-order responses currently,
  // as IDs are all set to `axi_tagctrl_pkg::AxReqId`
  typedef struct packed {
    logic [$bits(b_chan_slv_o.id)-1:0] id;
    axi_pkg::resp_t x_resp;
    logic tagged_req;
    logic illegal_req;
  } b_desc_t;

  //---------//
  // W stage //
  //---------//
  desc_t tagctrl_desc_d, tagctrl_desc_q;
  logic load_desc;
  enum logic {
    IDLE,
    SEND_W_CHANNEL
  }
      state_d, state_q;
  // tag cache payload accumulation
  axi_data_t tagc_w_data_d, tagc_w_data_q;
  logic store_tagc_data;
  axi_data_t tagc_w_bit_en_d, tagc_w_bit_en_q;
  logic store_tagc_bit_en;

  // Tag index bit (indicates if we are reading from a valid capability or not)
  logic [$clog2(TagFlitBits)-1:0] tag_bit_ind;
  // tag cache FIFO control signals
  logic tag_fifo_full;  // the FIFO is full
  logic tag_fifo_empty;  // the FIFO is empty
  logic tag_fifo_push;  // push data into the FIFO
  logic tag_fifo_pop;  // pop data from FIFO if it gets transferred
  tagc_oup_t tag_fifo_data;  // gets assigned to the tag cache write channel
  // memory W FIFO control signals
  logic w_mst_fifo_full;  // the FIFO is full
  logic w_mst_fifo_empty;  // the FIFO is empty
  logic w_mst_fifo_push;  // push data into the FIFO
  logic w_mst_fifo_pop;  // pop data from FIFO if it gets transferred
  w_chan_t w_mst_fifo_data;  // gets assigned to the w channel
  w_chan_t w_mst_fifo_indata;
  // pending B FIFO control signals
  logic b_fifo_full;
  logic b_fifo_empty;
  logic b_fifo_push;
  logic b_fifo_pop;
  b_desc_t b_fifo_indata;
  b_desc_t b_fifo_data;

  // Decode tag bit index based on the address
  assign tag_bit_ind = tagctrl_desc_q.a_x_addr[$clog2(Cfg.CapSize/8)+:$clog2(TagFlitBits)];

  // Tag cache output assignments
  assign tagc_oup_valid_o = ~tag_fifo_empty;
  assign tagc_oup_o = tag_fifo_data;
  assign tag_fifo_pop = tagc_oup_valid_o && tagc_oup_ready_i;

  // FIFO w beats memory assignments
  assign w_mst_fifo_pop = w_chan_mst_ready_i && w_chan_mst_valid_o;
  assign w_mst_fifo_indata = w_chan_slv_i;
  assign w_chan_mst_o = w_mst_fifo_data;
  assign w_chan_mst_valid_o = ~w_mst_fifo_empty;

  always_comb begin : w_chan_ctrl
    automatic axi_addr_t addr;
    automatic logic flush_tags;
    automatic logic stall;
    addr = '0;
    flush_tags = 1'b0;
    stall = 1'b0;
    // registers default values
    tagctrl_desc_d = tagctrl_desc_q;
    load_desc = 1'b0;
    tagc_w_data_d = tagc_w_data_q;
    store_tagc_data = 1'b0;
    tagc_w_bit_en_d = tagc_w_bit_en_q;
    store_tagc_bit_en = 1'b0;
    state_d = state_q;
    tag_fifo_indata = '0;
    tag_fifo_push = 1'b0;
    w_mst_fifo_push = 1'b0;
    b_fifo_indata = '0;
    b_fifo_push = 1'b0;
    // logic for handshake signals
    tagctrl_desc_ready_o = 1'b0;
    w_chan_slv_ready_o = 1'b0;

    case (state_q)
      IDLE: begin
        load_new_desc();
      end
      SEND_W_CHANNEL: begin
        // next beat address
        addr = axi_pkg::aligned_addr(
          tagctrl_desc_q.a_x_addr + axi_pkg::num_bytes(
            tagctrl_desc_q.a_x_size
          ),
          tagctrl_desc_q.a_x_size
        );
        // send a tag store package if this is the last beat or
        // the tag bits surpassed the data width
        flush_tags = (tag_bit_ind == (TagFlitBits - 1) && addr[0+:$clog2(Cfg.CapSize/8)] == 0)
                     || w_chan_slv_i.last;
        // wait if any of the downstream FIFOs needed by this beat is full
        stall = w_mst_fifo_full
                || (flush_tags && tag_fifo_full)
                || (w_chan_slv_i.last && b_fifo_full);
        w_chan_slv_ready_o = !stall;

        if (w_chan_slv_valid_i && !stall) begin
          w_mst_fifo_push = !tagctrl_desc_q.illegal_req;
          tagctrl_desc_d.a_x_addr = addr;
          load_desc = 1'b1;
          // accumulate tag bit
          tagc_w_data_d = tagc_w_data_q | (w_chan_slv_i.user << tag_bit_ind);
          tagc_w_bit_en_d = tagc_w_bit_en_q | (1 << tag_bit_ind);
          store_tagc_data = 1'b1;
          store_tagc_bit_en = 1'b1;
          if (flush_tags) begin
            tag_fifo_push = tagctrl_desc_q.tagged_req;
            tag_fifo_indata.data = tagc_w_data_d;
            tag_fifo_indata.bit_en = tagc_w_bit_en_d;
            tagc_w_data_d = '0;
            tagc_w_bit_en_d = '0;
          end
          if (w_chan_slv_i.last) begin
            // hand the write over to the B stage and move on
            b_fifo_push = 1'b1;
            b_fifo_indata.id = tagctrl_desc_q.a_x_id;
            b_fifo_indata.x_resp = tagctrl_desc_q.x_resp;
            b_fifo_indata.tagged_req = tagctrl_desc_q.tagged_req;
            b_fifo_indata.illegal_req = tagctrl_desc_q.illegal_req;
            load_new_desc();
          end
        end
      end
      // Go to Idle
      default: begin
        state_d = IDLE;
      end
    endcase
  end

  // this function loads a new descriptor from the `axi_tagctrl_ax.sv` unit
  function automatic void load_new_desc();
    tagctrl_desc_ready_o = 1'b1;
    state_d = IDLE;
    // new descriptor at the input
    if (tagctrl_desc_valid_i) begin
      tagctrl_desc_d = tagctrl_desc_i;
      load_desc = 1'b1;
      state_d = SEND_W_CHANNEL;
    end
  endfunction : load_new_desc

  //---------//
  // B stage //
  //---------//
  // Memory B responses, buffered so that they are always accepted (the FIFO holds one per write
  // that can be outstanding). The memory then never waits on tag cache progress, which may itself
  // need the memory for dirty leaf line write-backs. Tag cache B responses are buffered in
  // `axi_tagctrl_top.sv`.
  b_chan_t mem_b_data;
  logic mem_b_valid, mem_b_ready;

  always_comb begin : b_chan_ctrl
    automatic logic tagc_b_avail;
    tagc_b_avail = !b_fifo_data.tagged_req || tagc_resp_valid_i;
    // handshakes and outputs
    b_fifo_pop = 1'b0;
    mem_b_ready = 1'b0;
    tagc_resp_ready_o = 1'b0;
    b_chan_slv_valid_o = 1'b0;
    b_chan_slv_o = '0;

    if (!b_fifo_empty) begin
      if (b_fifo_data.illegal_req) begin
        // nothing was sent to memory or the tag cache, respond directly
        b_chan_slv_valid_o = 1'b1;
        b_chan_slv_o.id = b_fifo_data.id;
        b_chan_slv_o.resp = b_fifo_data.x_resp;
        b_fifo_pop = b_chan_slv_ready_i;
      end else if (mem_b_valid && tagc_b_avail) begin
        // both responses are in, merge them
        b_chan_slv_valid_o = 1'b1;
        b_chan_slv_o = mem_b_data;
        b_chan_slv_o.id = b_fifo_data.id;
        if (b_fifo_data.tagged_req && (tagc_resp_i.resp != axi_pkg::RESP_OKAY))
          b_chan_slv_o.resp = tagc_resp_i.resp;
        if (b_fifo_data.x_resp != axi_pkg::RESP_OKAY) b_chan_slv_o.resp = b_fifo_data.x_resp;
        if (b_chan_slv_ready_i) begin
          // response sent, retire the pending write
          b_fifo_pop = 1'b1;
          mem_b_ready = 1'b1;
          tagc_resp_ready_o = b_fifo_data.tagged_req;
        end
      end
    end
  end

  //-------//
  // FIFOs //
  //-------//

  // FIFO holds W beats to send to memory
  fifo_v3 #(
      .FALL_THROUGH(1'b1),               // FIFO is in fall-through mode
      .DEPTH       (Cfg.TagWFifoDepth),  // W beats buffered towards memory
      .dtype       (w_chan_t)
  ) i_w_mem_data_fifo (
      .clk_i     (clk_i),              // Clock
      .rst_ni    (rst_ni),             // Asynchronous reset active low
      .flush_i   ('0),                 // flush the queue
      .testmode_i(test_i),             // test_mode to bypass clock gating
      // status flags
      .full_o    (w_mst_fifo_full),    // queue is full
      .empty_o   (w_mst_fifo_empty),   // queue is empty
      .usage_o   (  /* not used */),   // fill pointer
      // as long as the queue is not full we can push new data
      .data_i    (w_mst_fifo_indata),  // data to push into the queue
      .push_i    (w_mst_fifo_push),    // data is valid and can be pushed to the queue
      // as long as the queue is not empty we can pop new elements
      .data_o    (w_mst_fifo_data),    // output data
      .pop_i     (w_mst_fifo_pop)      // pop head from queue
  );

  // FIFO holds tag flits to send to the tag cache
  fifo_v3 #(
      .FALL_THROUGH(1'b1),               // FIFO is in fall-through mode
      .DEPTH       (Cfg.TagBFifoDepth),  // one flit per in-flight tagged write
      .dtype       (tagc_oup_t)
  ) i_w_tags_data_fifo (
      .clk_i     (clk_i),             // Clock
      .rst_ni    (rst_ni),            // Asynchronous reset active low
      .flush_i   ('0),                // flush the queue
      .testmode_i(test_i),            // test_mode to bypass clock gating
      // status flags
      .full_o    (tag_fifo_full),     // queue is full
      .empty_o   (tag_fifo_empty),    // queue is empty
      .usage_o   (  /* not used */),  // fill pointer
      // as long as the queue is not full we can push new data
      .data_i    (tag_fifo_indata),   // data to push into the queue
      .push_i    (tag_fifo_push),     // data is valid and can be pushed to the queue
      // as long as the queue is not empty we can pop new elements
      .data_o    (tag_fifo_data),     // output data
      .pop_i     (tag_fifo_pop)       // pop head from queue
  );

  // FIFO holds writes whose W beats were all forwarded, waiting for B
  fifo_v3 #(
      .FALL_THROUGH(1'b0),
      .DEPTH       (Cfg.TagBFifoDepth),  // one entry per in-flight write
      .dtype       (b_desc_t)
  ) i_b_pending_fifo (
      .clk_i     (clk_i),
      .rst_ni    (rst_ni),
      .flush_i   ('0),
      .testmode_i(test_i),
      .full_o    (b_fifo_full),
      .empty_o   (b_fifo_empty),
      .usage_o   (  /* not used */),
      .data_i    (b_fifo_indata),
      .push_i    (b_fifo_push),
      .data_o    (b_fifo_data),
      .pop_i     (b_fifo_pop)
  );

  // FIFO holds memory B responses until the B stage merges them
  stream_fifo #(
      .FALL_THROUGH(1'b1),
      .DEPTH       (Cfg.TagBFifoDepth),  // one entry per in-flight write
      .T           (b_chan_t)
  ) i_mem_b_fifo (
      .clk_i,
      .rst_ni,
      .flush_i   (1'b0),
      .testmode_i(test_i),
      .usage_o   (  /* not used */),
      .data_i    (b_chan_mst_i),
      .valid_i   (b_chan_mst_valid_i),
      .ready_o   (b_chan_mst_ready_o),
      .data_o    (mem_b_data),
      .valid_o   (mem_b_valid),
      .ready_i   (mem_b_ready)
  );

  // Registers Flip Flops
  `FFLARN(state_q, state_d, '1, IDLE, clk_i, rst_ni)
  `FFLARN(tagctrl_desc_q, tagctrl_desc_d, load_desc, '0, clk_i, rst_ni)
  `FFLARN(tagc_w_data_q, tagc_w_data_d, store_tagc_data, '0, clk_i, rst_ni)
  `FFLARN(tagc_w_bit_en_q, tagc_w_bit_en_d, store_tagc_bit_en, '0, clk_i, rst_ni)

endmodule
