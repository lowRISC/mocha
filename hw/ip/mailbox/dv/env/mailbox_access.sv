// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// An AXI4-Lite access takes effect once between its request and response handshakes. The spec gives
// no tighter bound, so overlapping accesses may take effect in either order.
class mailbox_access;
  // Request-order ID, unique until reset
  int unsigned          id;
  mailbox_port_e        port;
  bit                   is_write;
  mailbox_access_kind_e kind = AccessOther;

  // Null if the request address maps to no register
  uvm_reg rg;

  // AW/AR and B/R handshake times
  realtime req_time;
  realtime rsp_time;

  // Response fields and write or read data, set when the access completes
  bit            done;
  logic [1:0]    resp;
  bit            ok;
  uvm_reg_data_t data;

  // Class specific methods
  extern function new(mailbox_port_e port, bit is_write, uvm_reg rg, realtime req_time);
  extern function string convert2string();
endclass : mailbox_access


function mailbox_access::new(mailbox_port_e port, bit is_write, uvm_reg rg, realtime req_time);
  this.port     = port;
  this.is_write = is_write;
  this.rg       = rg;
  this.req_time = req_time;
endfunction : new

function string mailbox_access::convert2string();
  return $sformatf("%0s of %0s on port %0s, request at %0t, response at %0t",
                   is_write ? "write" : "read", (rg == null) ? "no register" : rg.get_name(),
                   PortName[port], req_time, rsp_time);
endfunction : convert2string
