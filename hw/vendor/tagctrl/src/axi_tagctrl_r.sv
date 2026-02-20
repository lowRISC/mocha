// Copyright 2023 Bruno Sá and ZeroDay Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   29.11.2023

`include "common_cells/registers.svh"

/// [TODO] Description here

module axi_tagctrl_r #(
    /// Tag Controller configuration struct.This is passed down from
    /// [`axi_tagctrl_top`](module.axi_tagctrl_top).
    parameter axi_tagctrl_pkg::tagctrl_cfg_t Cfg = axi_tagctrl_pkg::tagctrl_cfg_t'{default: '0},
    /// Tag Controller descriptor type definition.
    parameter type tagctrl_desc_t = logic,
    /// Tag Cache R payload type definition.
    parameter type tagc_inp_t = logic,
    /// AXI slave port R channel struct definition.
    parameter type r_chan_t = logic
) (
    /// Clock, positive edge triggered.
    input logic clk_i,
    /// Asynchronous reset, active low.
    input logic rst_ni,
    /// Input descriptor payload.
    input tagctrl_desc_t tagctrl_desc_i,
    /// Input descriptor is valid.
    input logic tagctrl_desc_valid_i,
    /// Unit is ready to accept a new descriptor.
    output logic tagctrl_desc_ready_o,
    /// AXI R master channel payload.
    input r_chan_t r_chan_mst_i,
    /// AXI R channel is valid.
    input logic r_chan_valid_i,
    /// AXI R channel is ready.
    output logic r_chan_ready_o,
    /// Tag Cache R payload.
    input tagc_inp_t tagc_inp_r_i,
    /// Tag Cache R payload is valid.
    input logic tagc_inp_r_valid_i,
    /// Tag Cache R channel is ready .
    output logic tagc_inp_r_ready_o,
    /// Slave port R channel beat data.
    output r_chan_t r_chan_slv_o,
    /// R beat is valid.
    output logic r_chan_slv_valid_o,
    /// R beat is ready.
    input logic r_chan_slv_ready_i
);
  // Registers
  tagctrl_desc_t tagctrl_desc_d, tagctrl_desc_q;
  logic load_desc;
  enum logic [1:0] {
    IDLE,
    SEND_R_CHANNEL
  }
      state_d, state_q;
  // AXI tag cache channel signals
  tagc_inp_t tagc_inp_r_d, tagc_inp_r_q;
  logic tagc_inp_r_valid_d, tagc_inp_r_valid_q;
  logic load_tags, load_tags_valid;
  // MEM FIFO control signals
  logic mem_fifo_full;  // the FIFO is full
  logic mem_fifo_empty;  // the FIFO is full
  logic mem_fifo_push;  // push data into the FIFO
  logic mem_fifo_pop;  // pop data from FIFO if it gets transferred
  r_chan_t mem_fifo_data;  // gets assigned to the w channel
  r_chan_t mem_fifo_indata;
  // auxiliary signals
  // Tag index bit (indicates if we are reading from a valid capability or not)
  logic [$clog2(Cfg.AxiDataWidth)-1:0] tag_bit_ind;

  // AXI Slave R port channel assignments
  // AXI Master R port channel assignments
  assign r_chan_ready_o = !mem_fifo_full;
  // Decode tag bit index based on the address
  assign tag_bit_ind = tagctrl_desc_q.a_x_addr[$clog2(Cfg.CapSize/8)+:$clog2(Cfg.AxiDataWidth)];

  always_comb begin : r_chan_ctrl
    // registers default values
    state_d = state_q;
    tagctrl_desc_d = tagctrl_desc_q;
    load_desc = 1'b0;
    tagc_inp_r_d = tagc_inp_r_q;
    load_tags = 1'b0;
    tagc_inp_r_valid_d = tagc_inp_r_valid_q;
    load_tags_valid = 1'b0;
    mem_fifo_pop = 1'b0;
    // logic for handshake signals
    tagctrl_desc_ready_o = 1'b0;
    tagc_inp_r_ready_o = 1'b0;
    r_chan_slv_valid_o = 1'b0;
    // output signals
    r_chan_slv_o = '0;

    case (state_q)
      IDLE: begin
        load_new_desc();
        get_tags();
      end
      SEND_R_CHANNEL: begin
        if (tagc_inp_r_valid_q && !mem_fifo_empty) begin
          r_chan_slv_valid_o = 1'b1;
          mem_fifo_pop = r_chan_slv_ready_i;
          // update the address
          tagctrl_desc_d.a_x_addr = axi_pkg::aligned_addr(
            tagctrl_desc_q.a_x_addr + axi_pkg::num_bytes(
              tagctrl_desc_q.a_x_size
            ),
            tagctrl_desc_q.a_x_size
          );
          load_desc = r_chan_slv_ready_i;
          r_chan_slv_o = mem_fifo_data;
          // set id filled with the one from the descriptor
          r_chan_slv_o.id = tagctrl_desc_q.a_x_id;
          // set user field with the tag bit
          r_chan_slv_o.user = (tagc_inp_r_q.data >> tag_bit_ind) & 1;
          // load more tags if needed
          if ((tag_bit_ind == (Cfg.AxiDataWidth - 1) && tagctrl_desc_d.a_x_addr[0+:$clog2(
                  Cfg.CapSize/8
              )] == 0) && !mem_fifo_data.last && r_chan_slv_ready_i) begin
            get_tags();
          end
          if (mem_fifo_data.last && r_chan_slv_ready_i) begin
            load_new_desc();
            get_tags();
          end
        end
        if (!tagc_inp_r_valid_q) begin
          get_tags();
          mem_fifo_pop = 1'b0;
          r_chan_slv_valid_o = 1'b0;
          load_desc = 1'b0;
        end
      end
      // Go to Idle
      default: begin
        state_d = IDLE;
      end
    endcase

  end

  always_comb begin : r_chan_mst_fifo_ctrl
    mem_fifo_indata = '0;
    mem_fifo_push   = 1'b0;
    if (r_chan_valid_i && r_chan_ready_o) begin
      mem_fifo_push   = 1'b1;
      mem_fifo_indata = r_chan_mst_i;
    end
  end
  // this function loads a new descriptor from the `axi_tagctrl_ax.sv` unit
  function void load_new_desc();
    tagctrl_desc_ready_o = 1'b1;
    state_d = IDLE;
    // new descriptor at the input
    if (tagctrl_desc_valid_i) begin
      tagctrl_desc_d = tagctrl_desc_i;
      load_desc = 1'b1;
      state_d = SEND_R_CHANNEL;
    end
  endfunction : load_new_desc

  // this function loads a new descriptor from the `axi_tagctrl_ax.sv` unit
  function void get_tags();
    tagc_inp_r_ready_o = 1'b1;
    tagc_inp_r_valid_d = 1'b0;
    load_tags_valid = 1'b1;
    // new descriptor at the input
    if (tagc_inp_r_valid_i) begin
      tagc_inp_r_d = tagc_inp_r_i;
      load_tags = 1'b1;
      tagc_inp_r_valid_d = 1'b1;
      load_tags_valid = 1'b1;
    end
  endfunction : get_tags

  // FIFO holds R beats from mem
  fifo_v3 #(
      .FALL_THROUGH(1'b0),               // FIFO is in fall-through mode
      .DEPTH       (Cfg.TagRFifoDepth),  // can store up to 8 transactions
      .dtype       (r_chan_t)
  ) i_r_data_fifo (
      .clk_i     (clk_i),             // Clock
      .rst_ni    (rst_ni),            // Asynchronous reset active low
      .flush_i   ('0),                // flush the queue
      .testmode_i('0),                // test_mode to bypass clock gating
      // status flags
      .full_o    (mem_fifo_full),     // queue is full
      .empty_o   (mem_fifo_empty),    // queue is empty
      .usage_o   (  /* not used */),  // fill pointer
      // as long as the queue is not full we can push new data
      .data_i    (mem_fifo_indata),   // data to push into the queue
      .push_i    (mem_fifo_push),     // data is valid and can be pushed to the queue
      // as long as the queue is not empty we can pop new elements
      .data_o    (mem_fifo_data),     // output data
      .pop_i     (mem_fifo_pop)       // pop head from queue
  );

  // Registers Flip Flops
  `FFLARN(state_q, state_d, '1, IDLE, clk_i, rst_ni)
  `FFLARN(tagctrl_desc_q, tagctrl_desc_d, load_desc, '0, clk_i, rst_ni)
  `FFLARN(tagc_inp_r_q, tagc_inp_r_d, load_tags, '0, clk_i, rst_ni)
  `FFLARN(tagc_inp_r_valid_q, tagc_inp_r_valid_d, load_tags_valid, '0, clk_i, rst_ni)

endmodule
