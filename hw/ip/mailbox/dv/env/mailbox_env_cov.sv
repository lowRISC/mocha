// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Each MBOXW and MBOXR access, sampled per FIFO with the FIFO level before the access took effect.
// A write fails exactly when the FIFO is full and a read exactly when it is empty, so each
// coverpoint holds only the levels the specification allows for its kind and response.
covergroup fifo_cg (string name) with function sample(int unsigned          level,
                                                      mailbox_access_kind_e kind,
                                                      logic [1:0]           resp);
  option.per_instance = 1;
  option.name         = name;

  write_okay_cp: coverpoint level iff (kind == AccessMboxW && resp == RespOkay) {
    bins levels[] = {[0:MailboxDepth - 1]};
  }
  read_okay_cp: coverpoint level iff (kind == AccessMboxR && resp == RespOkay) {
    bins levels[] = {[1:MailboxDepth]};
  }
  write_slverr_cp: coverpoint level iff (kind == AccessMboxW && resp == RespSlverr) {
    bins full = {MailboxDepth};
  }
  read_slverr_cp: coverpoint level iff (kind == AccessMboxR && resp == RespSlverr) {
    bins empty = {0};
  }
endgroup : fifo_cg

// Each successful STATUS read, sampled per port. The flags are always sampled. The write side
// threshold and level are sampled only when w_known is set, and the read side ones when r_known is.
covergroup status_cg (string name) with function sample(bit          empty,
                                                        bit          full,
                                                        bit          wfifol,
                                                        bit          rfifol,
                                                        bit          w_known,
                                                        int unsigned wirqt,
                                                        int unsigned wlevel,
                                                        bit          r_known,
                                                        int unsigned rirqt,
                                                        int unsigned rlevel);
  option.per_instance = 1;
  option.name         = name;

  empty_cp: coverpoint empty {
    bins clear = {1'b0};
    bins set   = {1'b1};
  }
  full_cp: coverpoint full {
    bins clear = {1'b0};
    bins set   = {1'b1};
  }
  wfifol_cp: coverpoint wfifol {
    bins clear = {1'b0};
    bins set   = {1'b1};
  }
  rfifol_cp: coverpoint rfifol {
    bins clear = {1'b0};
    bins set   = {1'b1};
  }
  wirqt_cp: coverpoint wirqt iff (w_known) {
    bins values[] = {[0:MailboxDepth - 1]};
  }
  wlevel_cp: coverpoint wlevel iff (w_known) {
    bins levels[] = {[0:MailboxDepth]};
  }
  rirqt_cp: coverpoint rirqt iff (r_known) {
    bins values[] = {[0:MailboxDepth - 1]};
  }
  rlevel_cp: coverpoint rlevel iff (r_known) {
    bins levels[] = {[0:MailboxDepth]};
  }
  // WFIFOL and RFIFOL are set exactly while the level is above the threshold
  wfifol_cross: cross wfifol_cp, wirqt_cp, wlevel_cp iff (w_known) {
    ignore_bins inconsistent = wfifol_cross with (wfifol_cp != (wlevel_cp > wirqt_cp));
  }
  rfifol_cross: cross rfifol_cp, rirqt_cp, rlevel_cp iff (r_known) {
    ignore_bins inconsistent = rfifol_cross with (rfifol_cp != (rlevel_cp > rirqt_cp));
  }
endgroup : status_cg

// Each value written to WIRQT or RIRQT, sampled per port and register
covergroup threshold_cg (string name) with function sample(uvm_reg_data_t value);
  option.per_instance = 1;
  option.name         = name;

  value_cp: coverpoint value {
    bins below_depth[] = {[0:MailboxDepth - 1]};
    // Values within the field that clamp to MailboxDepth - 1
    bins clamped       = {[MailboxDepth:ThresholdMax]};
    bins reserved_set  = {[ThresholdMax + 1:$]};
  }
endgroup : threshold_cg

// Every access, sampled per port
covergroup access_cg (string name) with function sample(mailbox_reg_e rg,
                                                        bit           is_write,
                                                        bit           partial_strb,
                                                        logic [1:0]   resp);
  option.per_instance = 1;
  option.name         = name;

  reg_cp: coverpoint rg {
    bins regs[] = {[RegMboxW:RegCtrl]};
  }
  dir_cp: coverpoint is_write {
    bins read  = {1'b0};
    bins write = {1'b1};
  }
  strb_cp: coverpoint partial_strb iff (is_write) {
    bins full    = {1'b0};
    bins partial = {1'b1};
  }
  resp_cp: coverpoint resp {
    bins okay   = {RespOkay};
    bins slverr = {RespSlverr};
  }
  unmapped_cp: coverpoint is_write iff (rg == RegNone) {
    bins read  = {1'b0};
    bins write = {1'b1};
  }
  reg_dir_cross:  cross reg_cp, dir_cp;
  reg_strb_cross: cross reg_cp, strb_cp;
endgroup : access_cg

// Each OKAY MBOXW and MBOXR access: whether any access was in flight on the other port at some
// point during it, and each OKAY MBOXW or MBOXR there that overlapped it and answered first
covergroup concurrency_cg with function sample(mailbox_access_kind_e kind,
                                               bit                   overlap,
                                               bit                   has_other,
                                               mailbox_access_kind_e other_kind);
  kind_cp: coverpoint kind {
    bins mboxw = {AccessMboxW};
    bins mboxr = {AccessMboxR};
  }
  overlap_cp: coverpoint overlap {
    bins alone   = {1'b0};
    bins overlap = {1'b1};
  }
  other_cp: coverpoint other_kind iff (has_other) {
    bins mboxw = {AccessMboxW};
    bins mboxr = {AccessMboxR};
  }
  kind_overlap_cross: cross kind_cp, overlap_cp;
  kind_other_cross:   cross kind_cp, other_cp;
endgroup : concurrency_cg

// Each reset, with whether accesses were in flight and whether either FIFO held words. The second
// is sampled only when the scoreboard can tell.
covergroup reset_cg with function sample(bit in_flight, bit words_known, bit held_words);
  in_flight_cp: coverpoint in_flight {
    bins idle      = {1'b0};
    bins in_flight = {1'b1};
  }
  held_words_cp: coverpoint held_words iff (words_known) {
    bins empty = {1'b0};
    bins held  = {1'b1};
  }
  in_flight_held_words_cross: cross in_flight_cp, held_words_cp;
endgroup : reset_cg

// Functional coverage model, built when en_cov is set and sampled by the scoreboard once it has
// checked an access
class mailbox_env_cov extends uvm_component;
  `uvm_component_utils(mailbox_env_cov)

  // FIFO f holds MBOXW words from port f
  fifo_cg        m_fifo_cg[NumPorts];
  status_cg      m_status_cg[NumPorts];
  threshold_cg   m_wirqt_cg[NumPorts];
  threshold_cg   m_rirqt_cg[NumPorts];
  access_cg      m_access_cg[NumPorts];
  concurrency_cg m_concurrency_cg;
  reset_cg       m_reset_cg;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
endclass : mailbox_env_cov


function mailbox_env_cov::new(string name, uvm_component parent);
  super.new(name, parent);
  foreach (m_fifo_cg[i]) begin
    m_fifo_cg[i]   = new({"fifo_cg_", PortName[i]});
    m_status_cg[i] = new({"status_cg_", PortName[i]});
    m_wirqt_cg[i]  = new({"threshold_cg_wirqt_", PortName[i]});
    m_rirqt_cg[i]  = new({"threshold_cg_rirqt_", PortName[i]});
    m_access_cg[i] = new({"access_cg_", PortName[i]});
  end
  m_concurrency_cg = new();
  m_reset_cg       = new();
endfunction : new
