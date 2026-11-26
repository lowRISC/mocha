// Copyright 2023 Bruno Sá and ZeroDay Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   28.11.2023

/// [TODO] Place description here.
module axi_tagctrl_ax #(
    /// Tag Controller configuration struct. Passed down from `axi_tagctrl_top.sv`.
    parameter axi_tagctrl_pkg::tagctrl_cfg_t Cfg = axi_tagctrl_pkg::tagctrl_cfg_t'{default: '0},
    /// AXI Tag Controller descriptor type definition,
    parameter type desc_t = logic,
    /// AXI master port Ax channel type definition.
    parameter type ax_chan_t = logic,
    /// Type to hold AXI addresses
    parameter type axi_addr_t = logic [63:0]
) (
    /// Clock, positive edge triggered.
    input logic clk_i,
    /// Asynchronous reset, active low.
    input logic rst_ni,
    /// Tag bypassing mode
    input logic ignore_tags_i,
    /// Start of region covered by tags
    input axi_addr_t covered_base_addr_i,
    /// End of region covered by tags
    input axi_addr_t covered_top_addr_i,
    /// Start of region storing tags
    input axi_addr_t tag_store_base_addr_i,
    /// End of region storing tags
    input axi_addr_t tag_store_top_addr_i,
    /// AXI AX slave channel payload.
    input ax_chan_t ax_chan_slv_i,
    /// AXI AX slave channel is valid.
    input logic ax_chan_valid_i,
    /// AXI AX slave channel is ready.
    output logic ax_chan_ready_o,
    /// Output Tag cache descriptor payload.
    output desc_t tagc_desc_o,
    /// Output Tag cache descripor is valid.
    output logic tagc_valid_o,
    /// Tag cache is ready to receive a descriptor.
    input logic tagc_ready_i,
    /// AXI AX memory master channel payload.
    output ax_chan_t ax_mem_chan_mst_o,
    /// AXI AX memory master channel is valid.
    output logic ax_mem_chan_valid_o,
    /// AXI AX memory master channel is ready.
    input logic ax_mem_chan_ready_i,
    /// Output descriptor payload to `axi_tagctrl_x.sv`
    output desc_t tagctrl_desc_o,
    /// Output descriptor is valid
    output logic tagctrl_valid_o,
    /// Next unit is ready to receive a descriptor.
    input logic tagctrl_ready_i
);
  `include "common_cells/registers.svh"
  // local typedefs
  // master port ID is one bit wider than the slave port one, see `axi_mux`
  typedef logic [Cfg.AxiIdWidth:0] id_mst_t;

  // Register to hold the descriptor for tag controller pipeline
  desc_t tagctrl_desc_d, tagctrl_desc_q;
  logic tagctrl_desc_valid_d, tagctrl_desc_valid_q;
  logic load_tagctrl_desc, load_tagctrl_desc_valid;

  // Register to hold the descriptor for the tag cache
  desc_t tagc_desc_d, tagc_desc_q;
  logic tagc_desc_valid_d, tagc_desc_valid_q;
  logic load_tagc_desc, load_tagc_desc_valid;

  // Register to hold incoming AXI transaction
  ax_chan_t slv_chan_d, slv_chan_q;
  logic slv_chan_valid_d, slv_chan_valid_q;
  logic load_slv_chan, load_slv_chan_valid;

  // Auxiliary signals
  // Tag address offset to fetch
  axi_addr_t tag_addr;
  // End of the access
  axi_addr_t addr_end;
  // Whether the request attempts to directly access tags
  logic illegal_req;
  // Whether request is in the covered region
  logic tagged_req;

  // output assignments
  assign tagctrl_desc_o = tagctrl_desc_q;
  assign tagctrl_valid_o = tagctrl_desc_valid_q;
  assign tagc_desc_o = tagc_desc_q;
  assign tagc_valid_o = tagc_desc_valid_q;
  assign ax_mem_chan_mst_o = slv_chan_q;
  assign ax_mem_chan_valid_o = slv_chan_valid_q && !illegal_req;
  assign ax_chan_ready_o = ~slv_chan_valid_q && ~tagc_desc_valid_q && ~tagctrl_desc_valid_q;
  assign tag_addr = $unsigned(ax_chan_slv_i.addr - covered_base_addr_i) >> $clog2(Cfg.CapSize / 8);
  assign tagged_req = !ignore_tags_i
                      && ax_chan_slv_i.addr >= covered_base_addr_i
                      && ax_chan_slv_i.addr  <  covered_top_addr_i;
  assign addr_end = ax_chan_slv_i.addr + (axi_addr_t'(1 + ax_chan_slv_i.len) << ax_chan_slv_i.size);
  assign illegal_req = !ignore_tags_i
                      && ax_chan_slv_i.addr < tag_store_top_addr_i
                      && addr_end > tag_store_base_addr_i;
  // Note: testing the start address of the access (as opposed to the end)
  // against covered_top_addr_i is sufficient as AXI accesses are at most 4K
  // and covered_top_addr_i is at worst 8K aligned (or a config error is raised)

  always_comb begin : ax_mem_chan_ctrl
    // default assignments
    slv_chan_d = slv_chan_q;
    load_slv_chan = 1'b0;
    slv_chan_valid_d = slv_chan_valid_q;
    load_slv_chan_valid = 1'b0;

    if (slv_chan_valid_q) begin
      // send new request transaction
      if (ax_mem_chan_ready_i || illegal_req) begin
        slv_chan_valid_d = 1'b0;
        load_slv_chan_valid = 1'b1;
      end
    end else begin
      // handshake complete read the ax channel data if valid
      if (ax_chan_valid_i && ax_chan_ready_o) begin
        slv_chan_d = ax_chan_slv_i;
        slv_chan_d.id = id_mst_t'(axi_tagctrl_pkg::AxReqId);
        load_slv_chan = 1'b1;
        slv_chan_valid_d = 1'b1;
        load_slv_chan_valid = 1'b1;
      end
    end
  end

  always_comb begin : ax_tagc_desc_ctrl
    // default assignments
    tagc_desc_d = tagc_desc_q;
    load_tagc_desc = 1'b0;
    tagc_desc_valid_d = tagc_desc_valid_q;
    load_tagc_desc_valid = 1'b0;

    if (tagc_desc_valid_q) begin
      // send new request transaction
      if (tagc_ready_i) begin
        tagc_desc_valid_d = 1'b0;
        load_tagc_desc_valid = 1'b1;
      end
    end else begin
      // handshake complete read the ax channel data if valid
      if (ax_chan_valid_i && ax_chan_ready_o) begin
        tagc_desc_d = desc_t'{
            // assign the id value so that transactions are always order
            a_x_id:
            id_mst_t
            '(
            axi_tagctrl_pkg::AxReqId
            ),
            a_x_addr: tag_addr,
            a_x_len: 0,
            a_x_size: 0, // Supports 8 tag bits or less
            a_x_burst: axi_pkg::BURST_INCR,
            x_resp: illegal_req ? axi_pkg::RESP_DECERR : axi_pkg::RESP_OKAY,
            x_last: 1'b1,
            default: '0
        };
        load_tagc_desc = 1'b1;
        tagc_desc_valid_d = tagged_req;
        load_tagc_desc_valid = 1'b1;
      end
    end
  end

  always_comb begin : ax_tagctrl_desc_ctrl
    // default assignments
    tagctrl_desc_d = tagctrl_desc_q;
    load_tagctrl_desc = 1'b0;
    tagctrl_desc_valid_d = tagctrl_desc_valid_q;
    load_tagctrl_desc_valid = 1'b0;

    if (tagctrl_desc_valid_q) begin
      // send new request transaction
      if (tagctrl_ready_i) begin
        tagctrl_desc_valid_d = 1'b0;
        load_tagctrl_desc_valid = 1'b1;
      end
    end else begin
      // handshake complete read the ax channel data if valid
      if (ax_chan_valid_i && ax_chan_ready_o) begin
        tagctrl_desc_d = desc_t'{
            // save original slave id to respond correctly
            a_x_id:
            ax_chan_slv_i.id,
            a_x_addr: ax_chan_slv_i.addr,
            a_x_len: ax_chan_slv_i.len,
            a_x_size: ax_chan_slv_i.size,
            x_last: 1'b1,
            x_resp: illegal_req ? axi_pkg::RESP_DECERR : axi_pkg::RESP_OKAY,
            illegal_req: illegal_req,
            tagged_req: tagged_req,
            default: '0
        };
        load_tagctrl_desc = 1'b1;
        tagctrl_desc_valid_d = 1'b1;
        load_tagctrl_desc_valid = 1'b1;
      end
    end
  end

  // Registers
  `FFLARN(slv_chan_q, slv_chan_d, load_slv_chan, ax_chan_t'{default: '0}, clk_i, rst_ni)
  `FFLARN(slv_chan_valid_q, slv_chan_valid_d, load_slv_chan_valid, 1'b0, clk_i, rst_ni)
  `FFLARN(tagc_desc_q, tagc_desc_d, load_tagc_desc, desc_t'{default: '0}, clk_i, rst_ni)
  `FFLARN(tagc_desc_valid_q, tagc_desc_valid_d, load_tagc_desc_valid, 1'b0, clk_i, rst_ni)
  `FFLARN(tagctrl_desc_q, tagctrl_desc_d, load_tagctrl_desc, desc_t'{default: '0}, clk_i,
          rst_ni)
  `FFLARN(tagctrl_desc_valid_q, tagctrl_desc_valid_d, load_tagctrl_desc_valid, 1'b0, clk_i, rst_ni)

endmodule
