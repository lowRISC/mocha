// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Send one read beat; m_responses[0].m_rdata has the byte at m_addr least significant

class axi_single_read_seq extends axi_transfer_seq;
  `uvm_object_utils(axi_single_read_seq)

  // Standard SV/UVM methods
  extern function new(string name = "");

  extern constraint single_c;

  extern constraint read_c;
endclass: axi_single_read_seq


function axi_single_read_seq::new(string name = "");
  super.new(name);
endfunction: new

constraint axi_single_read_seq::single_c {
  m_req.m_len == 0;
}

constraint axi_single_read_seq::read_c {
  !m_write;
}
