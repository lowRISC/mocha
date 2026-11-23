// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Bridge AXI4-Lite and AXI4 structs using defaults for omitted signals (AMBA AXI H.c A9.3, B1.1.1):
// ID 0, AxLEN 0, AxSIZE the data bus width, AxBURST INCR, AxLOCK 0, AxCACHE 0b0000, QOS/REGION/USER
// 0 and WLAST 1

// An AXI4-Lite Manager in front of a full AXI4 Subordinate
module axi_agent_lite_to_full #(
  parameter int unsigned DataWidth   = 32,
  parameter type         lite_req_t  = logic,
  parameter type         lite_resp_t = logic,
  parameter type         req_t       = logic,
  parameter type         resp_t      = logic
) (
  input  lite_req_t  lite_req_i,
  output lite_resp_t lite_resp_o,
  output req_t       req_o,
  input  resp_t      resp_i
);
  localparam bit [2:0] Size = $clog2(DataWidth / 8);

  always_comb begin
    req_o          = '0;
    req_o.aw.addr  = lite_req_i.aw.addr;
    req_o.aw.prot  = lite_req_i.aw.prot;
    req_o.aw.size  = Size;
    req_o.aw.burst = axi_pkg::BURST_INCR;
    req_o.aw_valid = lite_req_i.aw_valid;
    req_o.w.data   = lite_req_i.w.data;
    req_o.w.strb   = lite_req_i.w.strb;
    req_o.w.last   = 1'b1;
    req_o.w_valid  = lite_req_i.w_valid;
    req_o.b_ready  = lite_req_i.b_ready;
    req_o.ar.addr  = lite_req_i.ar.addr;
    req_o.ar.prot  = lite_req_i.ar.prot;
    req_o.ar.size  = Size;
    req_o.ar.burst = axi_pkg::BURST_INCR;
    req_o.ar_valid = lite_req_i.ar_valid;
    req_o.r_ready  = lite_req_i.r_ready;

    lite_resp_o          = '0;
    lite_resp_o.aw_ready = resp_i.aw_ready;
    lite_resp_o.w_ready  = resp_i.w_ready;
    lite_resp_o.b.resp   = resp_i.b.resp;
    lite_resp_o.b_valid  = resp_i.b_valid;
    lite_resp_o.ar_ready = resp_i.ar_ready;
    lite_resp_o.r.data   = resp_i.r.data;
    lite_resp_o.r.resp   = resp_i.r.resp;
    lite_resp_o.r_valid  = resp_i.r_valid;
  end
endmodule : axi_agent_lite_to_full

// A full AXI4 Manager that only makes AXI4-Lite requests, in front of an AXI4-Lite Subordinate
module axi_agent_full_to_lite #(
  parameter type lite_req_t  = logic,
  parameter type lite_resp_t = logic,
  parameter type req_t       = logic,
  parameter type resp_t      = logic
) (
  input  req_t       req_i,
  output resp_t      resp_o,
  output lite_req_t  lite_req_o,
  input  lite_resp_t lite_resp_i
);
  always_comb begin
    lite_req_o          = '0;
    lite_req_o.aw.addr  = req_i.aw.addr;
    lite_req_o.aw.prot  = req_i.aw.prot;
    lite_req_o.aw_valid = req_i.aw_valid;
    lite_req_o.w.data   = req_i.w.data;
    lite_req_o.w.strb   = req_i.w.strb;
    lite_req_o.w_valid  = req_i.w_valid;
    lite_req_o.b_ready  = req_i.b_ready;
    lite_req_o.ar.addr  = req_i.ar.addr;
    lite_req_o.ar.prot  = req_i.ar.prot;
    lite_req_o.ar_valid = req_i.ar_valid;
    lite_req_o.r_ready  = req_i.r_ready;

    resp_o          = '0;
    resp_o.aw_ready = lite_resp_i.aw_ready;
    resp_o.w_ready  = lite_resp_i.w_ready;
    resp_o.b.resp   = lite_resp_i.b.resp;
    resp_o.b_valid  = lite_resp_i.b_valid;
    resp_o.ar_ready = lite_resp_i.ar_ready;
    resp_o.r.data   = lite_resp_i.r.data;
    resp_o.r.resp   = lite_resp_i.r.resp;
    resp_o.r.last   = 1'b1;
    resp_o.r_valid  = lite_resp_i.r_valid;
  end
endmodule : axi_agent_full_to_lite
