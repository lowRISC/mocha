// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`uvm_analysis_imp_decl(_main_req)
`uvm_analysis_imp_decl(_ext_req)
`uvm_analysis_imp_decl(_main_txn)
`uvm_analysis_imp_decl(_ext_txn)
`uvm_analysis_imp_decl(_reset)

// Check MBOXR data and order, MBOXW/MBOXR responses and every STATUS read against
// doc/proj/mailbox.md. FIFO f holds MBOXW words from port f for MBOXR on port 1 - f.
//
// Keep all states reachable by ordering accesses within their windows (see mailbox_access) that
// match previously checked responses; report a response no state explains. Check at the clock edge
// after each response to include all requests from that cycle. Report accesses outside the V1 model
// as errors.
class mailbox_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(mailbox_scoreboard)

  mailbox_env_cfg cfg;

  uvm_analysis_imp_main_req #(axi_mon_item, mailbox_scoreboard)   main_req_imp;
  uvm_analysis_imp_ext_req  #(axi_mon_item, mailbox_scoreboard)   ext_req_imp;
  uvm_analysis_imp_main_txn #(axi_mon_item, mailbox_scoreboard)   main_txn_imp;
  uvm_analysis_imp_ext_txn  #(axi_mon_item, mailbox_scoreboard)   ext_txn_imp;
  uvm_analysis_imp_reset    #(axi_reset_item, mailbox_scoreboard) reset_imp;

  // Per-port accesses awaiting responses, in request order
  local mailbox_access m_wr_pending[NumPorts][$];
  local mailbox_access m_rd_pending[NumPorts][$];

  // Completed accesses awaiting checks, in response order
  local mailbox_access m_to_check[$];

  // Unchecked modelled accesses in request order, and states consistent with checked responses
  local mailbox_access m_open[$];
  local mailbox_state  m_states[$];

  // Per-FIFO unmatched MBOXW writes and successful MBOXR reads
  local mailbox_access m_unread[NumPorts][$];
  local mailbox_access m_parked[NumPorts][$];

  local int unsigned m_num_accesses;

  // Checked words per FIFO, checked STATUS reads per port, and peak state count
  local int unsigned m_num_words[NumPorts];
  local int unsigned m_num_status[NumPorts];
  local int unsigned m_max_states;

  // Standard SV/UVM methods
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void check_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);

  // Class specific methods
  extern function void write_main_req(axi_mon_item item);
  extern function void write_ext_req(axi_mon_item item);
  extern function void write_main_txn(axi_mon_item item);
  extern function void write_ext_txn(axi_mon_item item);
  extern function void write_reset(axi_reset_item item);

  // Start tracking an access at its AW or AR handshake
  extern function void record_request(mailbox_port_e port, axi_mon_item item);

  // Complete the oldest pending access in this direction on the port
  extern function void record_response(mailbox_port_e port, axi_mon_item item);

  // Check responses older than the current time, or all responses if flush is set
  extern function void check_responses(bit flush = 1'b0);

  // Check MBOXW, MBOXR and STATUS accesses against the model
  extern function void check_mboxw(mailbox_access acc);
  extern function void check_mboxr(mailbox_access acc);
  extern function void check_status(mailbox_access acc);

  // Keep states matching the observed result. If none match, report under id and apply the observed
  // effect to every state.
  extern function void resolve(mailbox_access acc, mailbox_result_t observed, string id);

  // Try every order of open accesses in state until acc takes effect.
  //    found:   Collect states where acc produced the observed result, by key.
  //    allowed: Collect every result acc produced.
  extern function void explore(mailbox_state state, mailbox_access acc, mailbox_result_t observed,
                               ref mailbox_state found[string], ref bit allowed[string]);

  // Return whether m_open[idx] can take effect in state before acc's response
  extern function bit can_take_effect(mailbox_state state, int unsigned idx, mailbox_access acc);

  extern function string result2string(mailbox_access acc, mailbox_result_t result);

  // Match MBOXR words to FIFO writes in order, parking reads until the write response arrives
  extern function void match_words(int unsigned fifo);

  // Clear accesses and restore the reset state
  extern function void clear();
endclass : mailbox_scoreboard


function mailbox_scoreboard::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void mailbox_scoreboard::build_phase(uvm_phase phase);
  main_req_imp = new("main_req_imp", this);
  ext_req_imp  = new("ext_req_imp", this);
  main_txn_imp = new("main_txn_imp", this);
  ext_txn_imp  = new("ext_txn_imp", this);
  reset_imp    = new("reset_imp", this);
  clear();
endfunction : build_phase

task mailbox_scoreboard::run_phase(uvm_phase phase);
  forever begin
    @(cfg.clk_rst_vif.cb);
    check_responses();
  end
endtask : run_phase

function void mailbox_scoreboard::check_phase(uvm_phase phase);
  int unsigned num_words = 0;

  check_responses(.flush(1'b1));
  foreach (m_wr_pending[port]) begin
    if (m_wr_pending[port].size() > 0 || m_rd_pending[port].size() > 0) begin
      `uvm_error("END_OF_TEST",
                 $sformatf("%0d writes and %0d reads on port %0s had no response by the end",
                           m_wr_pending[port].size(), m_rd_pending[port].size(),
                           PortName[port]))
    end
  end
  foreach (m_parked[fifo]) begin
    if (m_parked[fifo].size() > 0) begin
      `uvm_error("END_OF_TEST",
                 $sformatf("%0d MBOXR words read on port %0s match no completed MBOXW write on %0s",
                           m_parked[fifo].size(), PortName[1 - fifo], PortName[fifo]))
    end
    num_words += m_num_words[fifo];
  end
  if (num_words < cfg.min_checked_words) begin
    `uvm_error("END_OF_TEST", $sformatf("%0d MBOXR words checked, the test expects at least %0d",
                                        num_words, cfg.min_checked_words))
  end
endfunction : check_phase

function void mailbox_scoreboard::report_phase(uvm_phase phase);
  foreach (m_num_words[i]) begin
    `uvm_info(`gfn, $sformatf("Port %0s: %0d words from port %0s and %0d STATUS reads checked",
                              PortName[1 - i], m_num_words[i], PortName[i], m_num_status[1 - i]),
              UVM_LOW)
  end
  `uvm_info(`gfn, $sformatf("At most %0d model states kept at once", m_max_states), UVM_LOW)
endfunction : report_phase

function void mailbox_scoreboard::write_main_req(axi_mon_item item);
  record_request(PortMain, item);
endfunction : write_main_req

function void mailbox_scoreboard::write_ext_req(axi_mon_item item);
  record_request(PortExt, item);
endfunction : write_ext_req

function void mailbox_scoreboard::write_main_txn(axi_mon_item item);
  record_response(PortMain, item);
endfunction : write_main_txn

function void mailbox_scoreboard::write_ext_txn(axi_mon_item item);
  record_response(PortExt, item);
endfunction : write_ext_txn

function void mailbox_scoreboard::write_reset(axi_reset_item item);
  if (item.m_in_reset) begin
    clear();
  end
endfunction : write_reset

function void mailbox_scoreboard::record_request(mailbox_port_e port, axi_mon_item item);
  mailbox_reg_block ral      = cfg.ral[port];
  bit               is_write = (item.get_dir() == AXI_WRITE);
  uvm_reg           rg       = ral.default_map.get_reg_by_offset(item.get_addr(), !is_write);
  mailbox_access    acc      = new(port, is_write, rg, $realtime);

  acc.id = m_num_accesses;
  m_num_accesses++;
  if (rg == null) begin
    `uvm_error("UNMODELLED",
               $sformatf({"%0s at 0x%0h: the response to an address with no register is open ",
                          "(lowRISC/mocha#755 item 9)"}, acc.convert2string(), item.get_addr()))
  end else if (is_write) begin
    if (rg == ral.mboxw) begin
      acc.kind = AccessMboxw;
      m_unread[port].push_back(acc);
    end else if (rg == ral.wirqt) begin
      acc.kind = AccessWirqt;
    end else if (rg == ral.rirqt) begin
      acc.kind = AccessRirqt;
    end else if (rg == ral.ctrl) begin
      `uvm_error("UNMODELLED", {acc.convert2string(), ": FIFO flushes are not modelled in V1"})
    end else if (rg != ral.irqs && rg != ral.irqen) begin
      `uvm_error("UNMODELLED", {acc.convert2string(), ": writes to read-only registers are not ",
                                "modelled in V1 (lowRISC/mocha#755 item 8)"})
    end
  end else begin
    if (rg == ral.mboxr) begin
      acc.kind = AccessMboxr;
    end else if (rg == ral.status) begin
      acc.kind = AccessStatus;
    end else if (rg == ral.mboxw || rg == ral.ctrl) begin
      `uvm_error("UNMODELLED", {acc.convert2string(), ": reads of write-only registers are not ",
                                "modelled in V1 (lowRISC/mocha#755 items 1, 2 and 8)"})
    end
  end

  if (is_write) begin
    m_wr_pending[port].push_back(acc);
  end else begin
    m_rd_pending[port].push_back(acc);
  end
  if (acc.kind != AccessOther) begin
    m_open.push_back(acc);
  end
endfunction : record_request

function void mailbox_scoreboard::record_response(mailbox_port_e port, axi_mon_item item);
  axi_mon_write_item wr_item;
  axi_mon_read_item  rd_item;
  mailbox_access     acc;

  if ($cast(wr_item, item)) begin
    if (m_wr_pending[port].size() == 0) begin
      `uvm_error("NO_REQUEST", $sformatf("B response on port %0s with no write waiting for one",
                                         PortName[port]))
      return;
    end
    acc      = m_wr_pending[port].pop_front();
    acc.resp = wr_item.m_bresp;
    acc.data = uvm_reg_data_t'(wr_item.m_wdata[0]);
    if (wr_item.m_wstrb[0] !== 'hff) begin
      `uvm_error("UNMODELLED",
                 $sformatf({"%0s with strobes 0x%0h: the effect of a partial write is open ",
                            "(lowRISC/mocha#755 item 10)"}, acc.convert2string(),
                           wr_item.m_wstrb[0]))
    end
  end else begin
    `downcast(rd_item, item)
    if (m_rd_pending[port].size() == 0) begin
      `uvm_error("NO_REQUEST", $sformatf("R response on port %0s with no read waiting for one",
                                         PortName[port]))
      return;
    end
    acc      = m_rd_pending[port].pop_front();
    acc.resp = rd_item.m_rresp[0];
    acc.data = uvm_reg_data_t'(rd_item.m_rdata[0]);
  end
  acc.done     = 1'b1;
  acc.ok       = (acc.resp === RespOkay);
  acc.rsp_time = $realtime;
  m_to_check.push_back(acc);
endfunction : record_response

function void mailbox_scoreboard::check_responses(bit flush = 1'b0);
  while (m_to_check.size() > 0 && (flush || m_to_check[0].rsp_time < $realtime)) begin
    mailbox_access acc = m_to_check.pop_front();

    unique case (acc.kind)
      AccessMboxw: begin
        check_mboxw(acc);
      end
      AccessMboxr: begin
        check_mboxr(acc);
      end
      AccessStatus: begin
        check_status(acc);
      end
      AccessWirqt, AccessRirqt: begin
        resolve(acc, '{resp: acc.resp, data: acc.ok ? mailbox_clamp_threshold(acc.data) : '0},
                "THRESHOLD");
      end
      default: begin
      end
    endcase
  end
endfunction : check_responses

function void mailbox_scoreboard::check_mboxw(mailbox_access acc);
  resolve(acc, '{resp: acc.resp, data: '0}, "MBOXW_RESP");
  match_words(acc.port);
endfunction : check_mboxw

function void mailbox_scoreboard::check_mboxr(mailbox_access acc);
  int unsigned fifo = 1 - acc.port;

  resolve(acc, '{resp: acc.resp, data: '0}, "MBOXR_RESP");
  if (acc.ok) begin
    m_parked[fifo].push_back(acc);
    match_words(fifo);
  end
endfunction : check_mboxr

function void mailbox_scoreboard::check_status(mailbox_access acc);
  m_num_status[acc.port]++;
  if (acc.ok && acc.data >> 4 != 0) begin
    `uvm_error("STATUS", $sformatf("%0s: read 0x%0h, the reserved bits are not zero",
                                   acc.convert2string(), acc.data))
  end
  resolve(acc, '{resp: acc.resp, data: acc.ok ? acc.data[3:0] : '0}, "STATUS");
endfunction : check_status

function void mailbox_scoreboard::resolve(mailbox_access acc, mailbox_result_t observed,
                                          string id);
  mailbox_state found[string];
  bit           allowed[string];
  int           open_idx[$] = m_open.find_first_index(open) with (open == acc);

  foreach (m_states[i]) begin
    explore(m_states[i], acc, observed, found, allowed);
  end

  if (found.size() == 0) begin
    string results;

    foreach (allowed[result]) begin
      results = (results == "") ? result : {results, " or ", result};
    end
    `uvm_error(id, $sformatf("%0s: %0s, but no order of the accesses in flight gives it, only %0s",
                             acc.convert2string(), result2string(acc, observed), results))
    foreach (m_states[i]) begin
      mailbox_state state = m_states[i].copy();

      state.force_result(acc, observed);
      found[state.key()] = state;
    end
  end

  m_open.delete(open_idx[0]);
  m_states.delete();
  foreach (found[key]) begin
    m_states.push_back(found[key]);
  end
  if (m_states.size() > m_max_states) begin
    m_max_states = m_states.size();
  end
endfunction : resolve

function void mailbox_scoreboard::explore(mailbox_state state, mailbox_access acc,
                                          mailbox_result_t observed,
                                          ref mailbox_state found[string],
                                          ref bit allowed[string]);
  if (state.results.exists(acc.id)) begin
    allowed[result2string(acc, state.results[acc.id])] = 1'b1;
    if (state.results[acc.id] === observed) begin
      mailbox_state next = state.copy();

      next.results.delete(acc.id);
      found[next.key()] = next;
    end
    return;
  end

  foreach (m_open[i]) begin
    mailbox_state next[$];

    if (can_take_effect(state, i, acc)) begin
      state.take_effect(m_open[i], next);
      foreach (next[j]) begin
        explore(next[j], acc, observed, found, allowed);
      end
    end
  end
endfunction : explore

function bit mailbox_scoreboard::can_take_effect(mailbox_state state, int unsigned idx,
                                                 mailbox_access acc);
  mailbox_access other = m_open[idx];

  if (state.results.exists(other.id) || other.req_time > acc.rsp_time) begin
    return 1'b0;
  end
  // AXI4-Lite has no IDs; preserve per-port request order separately for reads and writes
  for (int unsigned i = 0; i < idx; i++) begin
    if (m_open[i].port == other.port && m_open[i].is_write == other.is_write &&
        !state.results.exists(m_open[i].id)) begin
      return 1'b0;
    end
  end
  return 1'b1;
endfunction : can_take_effect

function string mailbox_scoreboard::result2string(mailbox_access acc, mailbox_result_t result);
  if (result.resp === RespSlverr) begin
    return "SLVERR";
  end else if (result.resp !== RespOkay) begin
    return $sformatf("response 0x%0h", result.resp);
  end else if (acc.kind == AccessStatus) begin
    return $sformatf("OKAY with flags 0x%0h", result.data);
  end else if (acc.kind == AccessWirqt || acc.kind == AccessRirqt) begin
    return $sformatf("OKAY holding %0d", result.data);
  end
  return "OKAY";
endfunction : result2string

function void mailbox_scoreboard::match_words(int unsigned fifo);
  while (m_parked[fifo].size() > 0) begin
    mailbox_access rd = m_parked[fifo][0];
    mailbox_access wr;

    // Failed writes add no word
    while (m_unread[fifo].size() > 0 && m_unread[fifo][0].done && !m_unread[fifo][0].ok) begin
      void'(m_unread[fifo].pop_front());
    end
    if (m_unread[fifo].size() == 0 || !m_unread[fifo][0].done) begin
      return;
    end

    wr = m_unread[fifo].pop_front();
    void'(m_parked[fifo].pop_front());
    m_num_words[fifo]++;
    if (rd.data != wr.data) begin
      `uvm_error("MBOXR_DATA", $sformatf("%0s: read 0x%0h, expected 0x%0h from the %0s",
                                         rd.convert2string(), rd.data, wr.data,
                                         wr.convert2string()))
    end
  end
endfunction : match_words

function void mailbox_scoreboard::clear();
  mailbox_state reset_state = new();

  m_to_check.delete();
  m_open.delete();
  m_states.delete();
  m_states.push_back(reset_state);
  m_num_accesses = 0;
  foreach (m_wr_pending[i]) begin
    m_wr_pending[i].delete();
    m_rd_pending[i].delete();
    m_unread[i].delete();
    m_parked[i].delete();
  end
endfunction : clear
