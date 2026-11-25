// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Each write burst, by the conditions that gate setting a tag: a tag is only set by a full
// capability write. mismatch is set when a capability-shaped burst's beats disagree on WUSER.
covergroup tag_write_cg with function sample(bit [7:0] len,
                                             bit [2:0] size,
                                             bit       aligned,
                                             bit       full_strobe,
                                             bit       user_any,
                                             bit       mismatch);
  option.per_instance = 1;

  len_cp: coverpoint len {
    bins single = {0};
    bins cap    = {1};
    bins multi  = {[2:255]};
  }
  size_cp: coverpoint size {
    bins word    = {3};
    bins subword = {[0:2]};
  }
  // The start address is 16-byte aligned
  align_cp: coverpoint aligned {
    bins aligned   = {1};
    bins unaligned = {0};
  }
  // Every beat had a full WSTRB
  strb_cp: coverpoint full_strobe {
    bins full    = {1};
    bins partial = {0};
  }
  // Any beat set WUSER
  user_cp: coverpoint user_any {
    bins with_tag = {1};
    bins no_tag   = {0};
  }
  mismatch_cp: coverpoint mismatch {
    bins match    = {0};
    bins mismatch = {1};
  }

  // Each gating condition crossed with the tag bit
  len_user_cross:   cross len_cp,   user_cp;
  align_user_cross: cross align_cp, user_cp;
  strb_user_cross:  cross strb_cp,  user_cp;
  size_user_cross:  cross size_cp,  user_cp;
endgroup : tag_write_cg

// Each read burst, with the RUSER of its first and last beat. A capability read returns the same
// tag on both beats, and a sub-word read returns no tag.
covergroup tag_read_cg with function sample(bit [7:0] len,
                                            bit [2:0] size,
                                            bit       first_user,
                                            bit       last_user);
  option.per_instance = 1;

  len_cp: coverpoint len {
    bins single = {0};
    bins cap    = {1};
    bins multi  = {[2:255]};
  }
  size_cp: coverpoint size {
    bins word    = {3};
    bins subword = {[0:2]};
  }
  // Both beats normally return the same tag. They can differ if a write to the same slot lands
  // between them, which is legal, so those values are ignored rather than flagged.
  ruser_pair_cp: coverpoint {last_user, first_user} iff (len == 8'd1) {
    bins both_clear   = {2'b00};
    bins both_set     = {2'b11};
    ignore_bins mixed = {2'b01, 2'b10};
  }
  subword_user_cp: coverpoint first_user iff (size != 3'd3) {
    bins cleared               = {0};
    ignore_bins unexpected_set = {1};
  }

  len_size_cross: cross len_cp, size_cp;
endgroup : tag_read_cg

// Samples the tag covergroups from the complete transactions of the agent's monitor.
class axi_sram_env_cov extends uvm_subscriber #(axi_mon_item);
  `uvm_component_utils(axi_sram_env_cov)

  tag_write_cg m_tag_write_cg;
  tag_read_cg  m_tag_read_cg;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void write(axi_mon_item t);

  // Class specific methods
  extern protected function void sample_write(axi_mon_write_item tr);

  extern protected function void sample_read(axi_mon_read_item tr);
endclass : axi_sram_env_cov


function axi_sram_env_cov::new(string name, uvm_component parent);
  super.new(name, parent);
  m_tag_write_cg = new();
  m_tag_read_cg  = new();
endfunction : new

function void axi_sram_env_cov::write(axi_mon_item t);
  axi_mon_write_item wr;
  axi_mon_read_item  rd;

  if ($cast(wr, t)) begin
    sample_write(wr);
  end else if ($cast(rd, t)) begin
    sample_read(rd);
  end
endfunction : write

function void axi_sram_env_cov::sample_write(axi_mon_write_item tr);
  bit aligned     = (tr.m_awaddr[3:0] == 4'd0);
  bit cap_shaped  = (tr.m_awlen == 8'd1) && (tr.m_awsize == 3'd3) && aligned;
  bit full_strobe = 1'b1;
  bit user_any    = 1'b0;
  bit mismatch    = 1'b0;

  foreach (tr.m_wstrb[i]) begin
    full_strobe &= (tr.m_wstrb[i][WordBytes-1:0] == '1);
    user_any    |= tr.m_wuser[i][0];
    mismatch    |= cap_shaped && (tr.m_wuser[i][0] != tr.m_wuser[0][0]);
  end
  m_tag_write_cg.sample(tr.m_awlen, tr.m_awsize, aligned, full_strobe, user_any, mismatch);
endfunction : sample_write

function void axi_sram_env_cov::sample_read(axi_mon_read_item tr);
  m_tag_read_cg.sample(tr.m_arlen, tr.m_arsize, tr.m_ruser[0][0], tr.m_ruser[$][0]);
endfunction : sample_read
