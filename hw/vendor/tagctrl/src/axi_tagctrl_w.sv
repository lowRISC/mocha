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
    parameter type tagctrl_desc_t = logic,
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
    input tagctrl_desc_t tagctrl_desc_i,
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
  typedef logic [Cfg.AxiIdWidth:0] axi_id_mst_t;
  typedef logic [Cfg.AxiDataWidth-1:0] axi_data_t;
  typedef logic [Cfg.AxiAddrWidth-1:0] axi_addr_t;
  // Registers
  tagctrl_desc_t tagctrl_desc_d, tagctrl_desc_q;
  logic load_desc;
  enum logic [1:0] {
    IDLE,
    SEND_W_CHANNEL,
    WAIT_B_CHAN_RESP
  }
      state_d, state_q;
  // tag cache payload signals
  axi_data_t tagc_w_data_d, tagc_w_data_q;
  logic store_tagc_data;
  axi_data_t tagc_w_bit_en_d, tagc_w_bit_en_q;
  logic store_tagc_bit_en;
  // response save
  b_chan_t mem_b_chan_d, mem_b_chan_q;
  logic mem_b_chan_valid_d, mem_b_chan_valid_q;
  logic en_mem_b_chan, en_mem_b_chan_valid;
  b_chan_t tagc_b_chan_d, tagc_b_chan_q;
  logic tagc_b_chan_valid_d, tagc_b_chan_valid_q;
  logic en_tagc_b_chan, en_tagc_b_chan_valid;


  // auxiliary signals
  // Tag index bit (indicates if we are reading from a valid capability or not)
  logic [$clog2(Cfg.AxiDataWidth)-1:0] tag_bit_ind;
  // tag cache FIFO control signals
  logic tag_fifo_full;  // the FIFO is full
  logic tag_fifo_empty;  // the FIFO is full
  logic tag_fifo_push;  // push data into the FIFO
  logic tag_fifo_pop;  // pop data from FIFO if it gets transferred
  tagc_oup_t tag_fifo_data;  // gets assigned to the w channel
  tagc_oup_t tag_fifo_indata;
  // tag cache FIFO control signals
  logic w_mst_fifo_full;  // the FIFO is full
  logic w_mst_fifo_empty;  // the FIFO is full
  logic w_mst_fifo_push;  // push data into the FIFO
  logic w_mst_fifo_pop;  // pop data from FIFO if it gets transferred
  w_chan_t w_mst_fifo_data;  // gets assigned to the w channel
  w_chan_t w_mst_fifo_indata;

  // Decode tag bit index based on the address
  assign tag_bit_ind = tagctrl_desc_q.a_x_addr[$clog2(Cfg.CapSize/8)+:$clog2(Cfg.AxiDataWidth)];

  // Tag cache output assignments
  assign tagc_oup_valid_o = ~tag_fifo_empty;
  assign tagc_oup_o = tag_fifo_data;
  assign tag_fifo_pop = tagc_oup_valid_o && tagc_oup_ready_i;

  // FIFO w beats memory assignments
  assign w_mst_fifo_pop = w_chan_mst_ready_i && w_chan_mst_valid_o && state_q == SEND_W_CHANNEL;
  assign w_mst_fifo_indata = w_chan_slv_i;
  assign w_chan_mst_o = w_mst_fifo_data;
  assign w_chan_mst_valid_o = !w_mst_fifo_empty && state_q == SEND_W_CHANNEL;

  always_comb begin : w_chan_ctrl
    automatic axi_addr_t addr;
    addr = '0;
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
    // logic for handshake signals
    tagctrl_desc_ready_o = 1'b0;
    w_chan_slv_ready_o = 1'b0;

    // logic for b channel
    b_chan_mst_ready_o = 1'b0;
    b_chan_slv_valid_o = 1'b0;
    tagc_resp_ready_o = 1'b0;
    mem_b_chan_d = mem_b_chan_q;
    en_mem_b_chan = 1'b0;
    mem_b_chan_valid_d = mem_b_chan_valid_q;
    en_mem_b_chan_valid = 1'b0;
    tagc_b_chan_d = tagc_b_chan_q;
    en_tagc_b_chan = 1'b0;
    tagc_b_chan_valid_d = tagc_b_chan_valid_q;
    en_tagc_b_chan_valid = 1'b0;


    case (state_q)
      IDLE: begin
        load_new_desc();
        tagc_b_chan_d = '0;
        en_tagc_b_chan = 1'b1;
        tagc_b_chan_valid_d = 1'b0;
        en_tagc_b_chan_valid = 1'b1;
        mem_b_chan_d = '0;
        en_mem_b_chan = 1'b1;
        mem_b_chan_valid_d = 1'b0;
        en_mem_b_chan_valid = 1'b1;
        store_tagc_bit_en = 1'b1;
        tagc_w_bit_en_d = '0;
      end
      SEND_W_CHANNEL: begin
        // handshake ready to receive beats from the slave interface
        w_chan_slv_ready_o = ~w_mst_fifo_full;
        // start sending beats if the master interface is ready
        // and there are valid beats on the slave interface
        if (w_chan_slv_valid_i) begin
          w_mst_fifo_push = 1'b1;
          // update the address
          addr = axi_pkg::aligned_addr(
            tagctrl_desc_q.a_x_addr + axi_pkg::num_bytes(
              tagctrl_desc_q.a_x_size
            ),
            tagctrl_desc_q.a_x_size
          );
          tagctrl_desc_d.a_x_addr = addr;
          load_desc = 1'b1;
          // store tag bit
          tagc_w_data_d = tagc_w_data_q | (w_chan_slv_i.user << tag_bit_ind);
          store_tagc_data = 1'b1;
          tagc_w_bit_en_d = tagc_w_bit_en_q | (1 << tag_bit_ind);
          store_tagc_bit_en = 1'b1;
          // send a tag store package if this is the last beat or
          // the tag bits surpassed the data witdth (I might remove this in a future to improve performance)
          if ((tag_bit_ind == (Cfg.AxiDataWidth - 1) && addr[0+:$clog2(
                  Cfg.CapSize/8
              )] == 0) || w_chan_slv_i.last) begin
            if (tag_fifo_full) begin
              // in case the tag write fifo to the tag cache is full we need to wait
              load_desc = 1'b0;
              tag_fifo_push = 1'b0;
              w_mst_fifo_push = 1'b0;
              w_chan_slv_ready_o = 1'b0;
            end else begin
              if (!w_mst_fifo_full) begin
                tag_fifo_push = 1'b1;
                tag_fifo_indata.data = tagc_w_data_d;
                tag_fifo_indata.strb = 8'b11111111;
                tag_fifo_indata.bit_en = tagc_w_bit_en_d;
                tagc_w_bit_en_d = '0;
                store_tagc_bit_en = 1'b1;
                tagc_w_data_d = '0;
                store_tagc_data = 1'b1;
              end
            end
          end
          if (w_mst_fifo_full) begin
            // in case the tag write fifo to the tag cache is full we need to wait
            load_desc = 1'b0;
            tag_fifo_push = 1'b0;
            w_mst_fifo_push = 1'b0;
            //w_chan_mst_valid_o = 1'b0;
            w_chan_slv_ready_o = 1'b0;
          end
        end
        if (w_chan_mst_o.last && w_mst_fifo_pop) begin
          state_d = WAIT_B_CHAN_RESP;
          b_chan_mst_ready_o = 1'b1;
          tagc_resp_ready_o = 1'b1;
          if (b_chan_slv_ready_i && b_chan_mst_valid_i && tagc_resp_valid_i) begin
            state_d = IDLE;
            b_chan_slv_o = b_chan_mst_i;
            b_chan_slv_o.id = tagctrl_desc_q.a_x_id;
            if (tagc_resp_i.resp != axi_pkg::RESP_OKAY) b_chan_slv_o.resp = tagc_resp_i.resp;
            b_chan_slv_valid_o = 1'b1;
          end else begin
            if (b_chan_mst_valid_i) begin
              mem_b_chan_d = b_chan_mst_i;
              en_mem_b_chan = 1'b1;
              mem_b_chan_valid_d = 1'b1;
              en_mem_b_chan_valid = 1'b1;
            end
            if (tagc_resp_valid_i) begin
              tagc_b_chan_d = tagc_resp_i;
              en_tagc_b_chan = 1'b1;
              tagc_b_chan_valid_d = 1'b1;
              en_tagc_b_chan_valid = 1'b1;
            end
          end
        end
      end
      WAIT_B_CHAN_RESP: begin
        b_chan_mst_ready_o = !mem_b_chan_valid_q;
        tagc_resp_ready_o  = !tagc_b_chan_valid_q;
        if (b_chan_mst_valid_i && !mem_b_chan_valid_q) begin
          mem_b_chan_d = b_chan_mst_i;
          en_mem_b_chan = 1'b1;
          mem_b_chan_valid_d = 1'b1;
          en_mem_b_chan_valid = 1'b1;
        end
        if (tagc_resp_valid_i && !tagc_b_chan_valid_q) begin
          tagc_b_chan_d = tagc_resp_i;
          en_tagc_b_chan = 1'b1;
          tagc_b_chan_valid_d = 1'b1;
          en_tagc_b_chan_valid = 1'b1;
        end
        if (mem_b_chan_valid_d && tagc_b_chan_valid_d) begin
          state_d = IDLE;
          b_chan_slv_o = mem_b_chan_d;
          b_chan_slv_o.id = tagctrl_desc_q.a_x_id;
          if (tagc_b_chan_d.resp != axi_pkg::RESP_OKAY) b_chan_slv_o.resp = tagc_b_chan_d.resp;
          b_chan_slv_valid_o = 1'b1;
        end
      end
      // Go to Idle
      default: begin
        state_d = IDLE;
      end
    endcase

  end
  // this function loads a new descriptor from the `axi_tagctrl_ax.sv` unit
  function void load_new_desc();
    tagctrl_desc_ready_o = 1'b1;
    state_d = IDLE;
    // new descriptor at the input
    if (tagctrl_desc_valid_i) begin
      tagctrl_desc_d = tagctrl_desc_i;
      load_desc = 1'b1;
      state_d = SEND_W_CHANNEL;
    end
  endfunction : load_new_desc


  // FIFO holds W beats to send to memory
  fifo_v3 #(
      .FALL_THROUGH(1'b1),               // FIFO is in fall-through mode
      .DEPTH       (Cfg.TagWFifoDepth),  // can store up to 2 transactions
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

  // FIFO holds W beats to send to the tag cache
  fifo_v3 #(
      .FALL_THROUGH(1'b1),               // FIFO is in fall-through mode
      .DEPTH       (Cfg.TagWFifoDepth),  // can store up to 2 transactions
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

  // Registers Flip Flops
  `FFLARN(state_q, state_d, '1, IDLE, clk_i, rst_ni)
  `FFLARN(tagctrl_desc_q, tagctrl_desc_d, load_desc, '0, clk_i, rst_ni)
  `FFLARN(tagc_w_data_q, tagc_w_data_d, store_tagc_data, '0, clk_i, rst_ni)
  `FFLARN(tagc_w_bit_en_q, tagc_w_bit_en_d, store_tagc_bit_en, '0, clk_i, rst_ni)
  `FFLARN(mem_b_chan_q, mem_b_chan_d, en_mem_b_chan, '0, clk_i, rst_ni)
  `FFLARN(mem_b_chan_valid_q, mem_b_chan_valid_d, en_mem_b_chan_valid, '0, clk_i, rst_ni)
  `FFLARN(tagc_b_chan_q, tagc_b_chan_d, en_tagc_b_chan, '0, clk_i, rst_ni)
  `FFLARN(tagc_b_chan_valid_q, tagc_b_chan_valid_d, en_tagc_b_chan_valid, '0, clk_i, rst_ni)

endmodule
