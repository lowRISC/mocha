// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Response policy for one AXI transaction

class axi_sub_rsp_item extends uvm_sequence_item;
  `uvm_object_utils(axi_sub_rsp_item)

  // Minimum cycles before BVALID or first RVALID once the transaction is answerable
  rand int unsigned m_latency;

  // Answer with m_error_resp: the B response of a write, or every beat of a read
  rand bit m_force_error;

  rand axi_resp_e m_error_resp;

  // BUSER or RUSER, truncated to the interface width
  rand bit [AxiMaxRespUserWidth-1:0] m_buser;
  rand bit [AxiMaxRUserWidth-1:0]    m_ruser;

  // Randomization bounds for m_latency
  int unsigned m_latency_min = 0;
  int unsigned m_latency_max = 0;

  // The percentage of transactions that should carry m_force_error
  int unsigned m_error_pct = 0;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern function void do_copy(uvm_object rhs);
  extern function string convert2string();

  extern constraint latency_c;

  extern constraint force_error_c;

  extern constraint error_pct_c;

  // Injected errors must be SLVERR or DECERR (AMBA AXI H.c A3.4.5)
  extern constraint error_resp_c;
endclass : axi_sub_rsp_item


function axi_sub_rsp_item::new(string name = "");
  super.new(name);
endfunction : new

function void axi_sub_rsp_item::do_copy(uvm_object rhs);
  axi_sub_rsp_item rhs_;

  if (rhs == null) begin
    `uvm_fatal("do_copy", "Cannot copy from RHS: it is null.")
  end
  if (!$cast(rhs_, rhs)) begin
    `uvm_fatal("do_copy", "Cannot cast RHS: wrong type?")
  end

  super.do_copy(rhs);
  m_latency     = rhs_.m_latency;
  m_force_error = rhs_.m_force_error;
  m_error_resp  = rhs_.m_error_resp;
  m_buser       = rhs_.m_buser;
  m_ruser       = rhs_.m_ruser;
  m_latency_min = rhs_.m_latency_min;
  m_latency_max = rhs_.m_latency_max;
  m_error_pct   = rhs_.m_error_pct;
endfunction : do_copy

function string axi_sub_rsp_item::convert2string();
  return $sformatf("m_latency = %0d, m_force_error = %0d, m_error_resp = %0s", m_latency,
                   m_force_error, m_error_resp.name());
endfunction : convert2string

constraint axi_sub_rsp_item::latency_c {
  m_latency inside {[m_latency_min : m_latency_max]};
}

constraint axi_sub_rsp_item::force_error_c {
  m_force_error dist {1'b1 :/ m_error_pct, 1'b0 :/ 100 - m_error_pct};
}

constraint axi_sub_rsp_item::error_pct_c {
  m_error_pct <= 100;
}

constraint axi_sub_rsp_item::error_resp_c {
  m_error_resp inside {RespSlverr, RespDecerr};
}
