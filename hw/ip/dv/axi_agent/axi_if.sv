// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Five AXI channels with a shared clock and reset. Configure bus widths at run time through the
// set_* functions, which update all affected channels. Call set_user_width before set_data_width:
// DATA_WIDTH must be at least twice USER_DATA_WIDTH.

interface axi_if (input logic clk_i, input logic rst_ni);
  import axi_agent_pkg::axi_if_mode_e;
  import axi_agent_pkg::Manager;
  import axi_agent_pkg::Subordinate;
  import axi_agent_pkg::Monitor;

  // Set the mode with set_if_mode(). Manager drives AW, W, AR, BREADY and RREADY; Subordinate
  // drives B, R, AWREADY, WREADY and ARREADY; Monitor is passive.
  axi_if_mode_e if_mode = Monitor;

  // Set AXI4-Lite mode with set_lite()
  bit is_lite = 1'b0;

  // Idle payload policy for AW, W and AR in Manager mode and B and R in Subordinate mode. With
  // VALID low, drive X on all other fields when set, or random values when clear. X exposes
  // sampling outside a handshake. Set with set_drive_x_when_idle().
  bit drive_x_when_idle = 1'b1;

  // Clock and reset are driven externally
  clk_rst_if u_clk_rst_if (.clk(clk_i), .rst_n(rst_ni));

  axi_write_request_if  aw_if (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_data_if     w_if  (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_write_response_if b_if  (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_request_if   ar_if (.clk_i(clk_i), .rst_ni(rst_ni));
  axi_read_data_if      r_if  (.clk_i(clk_i), .rst_ni(rst_ni));

  function automatic void set_if_mode(axi_if_mode_e mode);
    if_mode       = mode;
    aw_if.if_mode = mode;
    w_if.if_mode  = mode;
    b_if.if_mode  = mode;
    ar_if.if_mode = mode;
    r_if.if_mode  = mode;
  endfunction: set_if_mode

  function automatic void set_addr_width(int unsigned width);
    aw_if.set_addr_width(width);
    ar_if.set_addr_width(width);
  endfunction: set_addr_width

  function automatic void set_data_width(int unsigned width);
    w_if.set_data_width(width);
    r_if.set_data_width(width);
  endfunction: set_data_width

  function automatic void set_id_width(int unsigned width);
    aw_if.set_id_w_width(width);
    b_if.set_id_w_width(width);
    ar_if.set_id_r_width(width);
    r_if.set_id_r_width(width);
  endfunction: set_id_width

  function automatic void set_user_width(int unsigned width);
    aw_if.set_user_req_width(width);
    ar_if.set_user_req_width(width);
    w_if.set_user_data_width(width);
    r_if.set_user_data_width(width);
    b_if.set_user_resp_width(width);
    r_if.set_user_resp_width(width);
  endfunction: set_user_width

  // AXI4-Lite has no ID or USER signals, so their widths are set to zero (AMBA AXI H.c B1.1.1)
  function automatic void set_lite(bit lite);
    is_lite = lite;
    if (lite) begin
      set_id_width(0);
      set_user_width(0);
    end
  endfunction: set_lite

  function automatic void set_drive_x_when_idle(bit drive_x);
    drive_x_when_idle = drive_x;
  endfunction: set_drive_x_when_idle
endinterface: axi_if
