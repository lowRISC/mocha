// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// One possible model state: FIFO levels, per-port thresholds and unchecked access results. New
// states start with reset values.
class mailbox_state;
  // FIFO f holds MBOXW words from port f
  int unsigned level[NumPorts];

  uvm_reg_data_t wirqt[NumPorts];
  uvm_reg_data_t rirqt[NumPorts];

  // Results of accesses that took effect but have not been checked, keyed by access ID
  mailbox_result_t results[int unsigned];

  // Model values that unchecked MBOXW, MBOXR and STATUS accesses saw, keyed by access ID, for
  // coverage
  mailbox_seen_t seen[int unsigned];

  // Class specific methods
  extern function mailbox_state copy();

  // Apply acc and append states to next, branching over WIRQT/RIRQT values because write data is
  // unknown until the response
  extern function void take_effect(mailbox_access acc, ref mailbox_state next[$]);

  // Replace any effect of acc with the effect of its observed result
  extern function void force_result(mailbox_access acc, mailbox_result_t observed);

  // Return STATUS bits 3:0: RFIFOL, WFIFOL, FULL and EMPTY
  extern function uvm_reg_data_t status(mailbox_port_e port);

  // Return an equality key for the state
  extern function string key();
endclass : mailbox_state


function mailbox_state mailbox_state::copy();
  mailbox_state state = new();

  state.level   = level;
  state.wirqt   = wirqt;
  state.rirqt   = rirqt;
  state.results = results;
  state.seen    = seen;
  return state;
endfunction : copy

function void mailbox_state::take_effect(mailbox_access acc, ref mailbox_state next[$]);
  int unsigned     fifo   = (acc.kind == AccessMboxR) ? 1 - acc.port : acc.port;
  mailbox_state    state  = copy();
  mailbox_result_t result = '{resp: RespOkay, data: '0};

  if (acc.kind inside {AccessMboxW, AccessMboxR, AccessStatus}) begin
    state.seen[acc.id] = '{level: level, wirqt: wirqt, rirqt: rirqt};
  end
  unique case (acc.kind)
    AccessMboxW: begin
      if (level[fifo] < MailboxDepth) begin
        state.level[fifo]++;
      end else begin
        result.resp = RespSlverr;
      end
    end
    AccessMboxR: begin
      if (level[fifo] > 0) begin
        state.level[fifo]--;
      end else begin
        result.resp = RespSlverr;
      end
    end
    AccessStatus: begin
      result.data = status(acc.port);
    end
    AccessWIrqT, AccessRIrqT: begin
      for (int unsigned value = 0; value < MailboxDepth; value++) begin
        mailbox_state branch = copy();

        if (acc.kind == AccessWIrqT) begin
          branch.wirqt[acc.port] = value;
        end else begin
          branch.rirqt[acc.port] = value;
        end
        branch.results[acc.id] = '{resp: RespOkay, data: value};
        next.push_back(branch);
      end
      return;
    end
    default: begin
      `uvm_fatal("mailbox_state", {acc.convert2string(), ": the model has no effect for it"})
    end
  endcase
  state.results[acc.id] = result;
  next.push_back(state);
endfunction : take_effect

function void mailbox_state::force_result(mailbox_access acc, mailbox_result_t observed);
  int unsigned fifo   = (acc.kind == AccessMboxR) ? 1 - acc.port : acc.port;
  bit          is_ok  = (observed.resp === RespOkay);
  bit          was_ok = 1'b0;
  int          new_level;

  if (results.exists(acc.id)) begin
    was_ok = (results[acc.id].resp === RespOkay);
    results.delete(acc.id);
  end
  seen.delete(acc.id);

  // Only successful accesses move words
  unique case (acc.kind)
    AccessMboxW: begin
      new_level = int'(level[fifo]) + int'(is_ok) - int'(was_ok);
    end
    AccessMboxR: begin
      new_level = int'(level[fifo]) - int'(is_ok) + int'(was_ok);
    end
    AccessWIrqT: begin
      new_level = level[fifo];
      if (is_ok) begin
        wirqt[acc.port] = observed.data;
      end
    end
    AccessRIrqT: begin
      new_level = level[fifo];
      if (is_ok) begin
        rirqt[acc.port] = observed.data;
      end
    end
    default: begin
      new_level = level[fifo];
    end
  endcase
  level[fifo] = (new_level < 0) ? 0 : (new_level > MailboxDepth) ? MailboxDepth : new_level;
endfunction : force_result

function uvm_reg_data_t mailbox_state::status(mailbox_port_e port);
  int unsigned wfifo = port;
  int unsigned rfifo = 1 - port;

  return {level[rfifo] > rirqt[port], level[wfifo] > wirqt[port], level[wfifo] == MailboxDepth,
          level[rfifo] == 0};
endfunction : status

function string mailbox_state::key();
  string text = $sformatf("%p %p %p", level, wirqt, rirqt);

  foreach (results[id]) begin
    text = {text, $sformatf(" %0d:%0h:%0h", id, results[id].resp, results[id].data)};
  end
  foreach (seen[id]) begin
    text = {text, $sformatf(" %0d:%p", id, seen[id])};
  end
  return text;
endfunction : key
