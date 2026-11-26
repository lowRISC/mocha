// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // What tagctrl_predictor accepts as the outcome of one access, and how an observed access is
  // compared against it. The specification often allows more than one outcome, so an expectation
  // holds a set of acceptable values or leaves parts unchecked, rather than a single value.
  virtual class tagctrl_exp extends uvm_object;

    // What the last compare checked: read bytes, chunks whose tag was required clear, and chunks
    // whose tag was required set
    int unsigned n_bytes_checked;
    int unsigned n_clear_tags_checked;
    int unsigned n_set_tags_checked;

    function new(string name = "");
      super.new(name);
    endfunction

    // Compare an observed access, adding a description of each mismatch to errors
    pure virtual function void compare(axi_mon_item item, ref string errors[$]);
  endclass

  // An access to the configuration subordinate (tag_controller.adoc:230-519)
  class tagctrl_cfg_exp extends tagctrl_exp;
    `uvm_object_utils(tagctrl_cfg_exp)

    bit [11:0] offset;

    // A read returns a value in [lo, hi] aligned to align; unchecked unless check_value is set
    bit        check_value;
    bit [63:0] lo, hi;
    bit [63:0] align = 1;

    // A status read shows one of states and, if check_error is set, no error
    bit        is_status;
    bit [3:0]  states;
    bit        check_error;

    function new(string name = "tagctrl_cfg_exp");
      super.new(name);
    endfunction

    // tag_controller.adoc:303: every access answers OKAY, including a write to a read-only
    // register
    function void compare(axi_mon_item item, ref string errors[$]);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      logic [63:0]       data;

      if ($cast(wr, item)) begin
        if (wr.m_bresp !== RespOkay) begin
          errors.push_back($sformatf("write to 0x%03h answered %0d, expected OKAY", offset,
                                     wr.m_bresp));
        end
        return;
      end
      void'($cast(rd, item));
      if (rd.m_rresp[0] !== RespOkay) begin
        errors.push_back($sformatf("read of 0x%03h answered %0d, expected OKAY", offset,
                                   rd.m_rresp[0]));
      end
      data = rd.m_rdata[0][63:0];
      if ($isunknown(data)) begin
        errors.push_back($sformatf("read of 0x%03h returned 0x%016h with X or Z bits", offset,
                                   data));
      end else if (is_status) begin
        compare_status(data, errors);
      end else if (check_value && lo == hi && data != lo) begin
        errors.push_back($sformatf("read of 0x%03h returned 0x%016h, expected 0x%016h", offset,
                                   data, lo));
      end else if (check_value && (data < lo || data > hi)) begin
        errors.push_back($sformatf("read of 0x%03h returned 0x%016h, expected 0x%016h to 0x%016h",
                                   offset, data, lo, hi));
      end else if (check_value && data % align != 0) begin
        errors.push_back($sformatf("read of 0x%03h returned 0x%016h, not aligned to %0d bytes",
                                   offset, data, align));
      end
    endfunction

    // tag_controller.adoc:306-326: reserved bits read 0, Locked is clear since the controller is
    // never locked, and exactly one state bit is set
    local function void compare_status(bit [63:0] data, ref string errors[$]);
      bit [3:0] st = data[3:0];
      if (data & StatusReservedMask) begin
        errors.push_back($sformatf("status 0x%016h sets reserved bits", data));
      end
      if (data[StatusLocked]) begin
        errors.push_back($sformatf("status 0x%016h: Locked is set", data));
      end
      if (check_error && (data & StatusErrorMask)) begin
        errors.push_back($sformatf("status 0x%016h: error %0d, expected 0", data, data[23:16]));
      end
      if ($countones(st) != 1) begin
        errors.push_back($sformatf("status 0x%016h: state bits are not one-hot", data));
      end else if (!(st & states)) begin
        errors.push_back($sformatf("status 0x%016h: state bits 0b%04b, expected one of 0b%04b",
                                   data, st, states));
      end
    endfunction
  endclass

  // An access to the tagged subordinate
  class tagctrl_tag_exp extends tagctrl_exp;
    `uvm_object_utils(tagctrl_tag_exp)

    typedef struct {
      // Whether a read may return the tag set, and whether it must when the chunk is read whole
      bit may_be_set;
      bit set_if_whole;
    } chunk_exp_t;

    axi_addr_t addr;

    // Reads, per beat: the aligned address of the beat, its byte lanes, the expected bytes, and
    // which lanes are predicted
    bit [63:0]   beat_base[];
    int unsigned lower[];
    int unsigned upper[];
    bit [63:0]   data[];
    bit [7:0]    known[];

    // Reads, per chunk touched, by address / ChunkBytes; a chunk absent is not checked
    chunk_exp_t chunks[bit [63:0]];

    function new(string name = "tagctrl_tag_exp");
      super.new(name);
    endfunction

    function void compare(axi_mon_item item, ref string errors[$]);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;

      n_bytes_checked      = 0;
      n_clear_tags_checked = 0;
      n_set_tags_checked   = 0;
      if ($cast(wr, item)) begin
        void'(check_resp("write", wr.m_bresp, errors));
        return;
      end
      void'($cast(rd, item));
      compare_read(rd, errors);
    endfunction

    // tag_controller.adoc:108-109, 127-134: an access outside the tag table is forwarded, so it
    // answers OKAY
    local function bit check_resp(string what, logic [1:0] resp, ref string errors[$]);
      if (resp !== RespOkay) begin
        errors.push_back($sformatf("%s at 0x%0h answered %0d, expected OKAY", what, addr, resp));
      end
      return resp === RespOkay;
    endfunction

    // A chunk's tag is read from the RUSER of the beats that carry its bytes: set if any of them
    // is set, which the specification does not settle. A set tag is only required of a chunk read
    // whole, since the specification does not say what RUSER carries for part of a chunk.
    local function void compare_read(axi_mon_read_item rd, ref string errors[$]);
      int unsigned chunk_bytes[bit [63:0]];
      bit          seen_set[bit [63:0]];

      foreach (rd.m_rdata[n]) begin
        logic user = rd.m_ruser[n][0];
        if (!check_resp($sformatf("read beat %0d", n), rd.m_rresp[n], errors)) continue;
        if (n >= beat_base.size()) continue;
        for (int unsigned lane = lower[n]; lane <= upper[n]; lane++) begin
          bit [63:0]  a     = beat_base[n] + lane;
          bit [63:0]  chunk = a / ChunkBytes;
          logic [7:0] got   = rd.m_rdata[n][8*lane +: 8];
          if (known[n][lane]) begin
            n_bytes_checked++;
            if (got !== data[n][8*lane +: 8]) begin
              errors.push_back($sformatf("read of 0x%0h returned 0x%02h at 0x%0h, expected 0x%02h",
                                         addr, got, a, data[n][8*lane +: 8]));
            end
          end
          if (!chunk_bytes.exists(chunk)) begin
            chunk_bytes[chunk] = 0;
            seen_set[chunk]    = 1'b0;
          end
          chunk_bytes[chunk]++;
          if (user !== 1'b0) seen_set[chunk] = 1'b1;
        end
      end

      foreach (chunk_bytes[c]) begin
        bit must_be_set;
        if (!chunks.exists(c)) continue;
        must_be_set = chunks[c].set_if_whole && chunk_bytes[c] >= ChunkBytes;
        if (!chunks[c].may_be_set) n_clear_tags_checked++;
        if (must_be_set) n_set_tags_checked++;
        if (seen_set[c] && !chunks[c].may_be_set) begin
          errors.push_back($sformatf("read of 0x%0h returned a set tag for chunk 0x%0h", addr,
                                     c * ChunkBytes));
        end
        if (!seen_set[c] && must_be_set) begin
          errors.push_back($sformatf("read of 0x%0h returned a clear tag for chunk 0x%0h", addr,
                                     c * ChunkBytes));
        end
      end
    endfunction
  endclass
