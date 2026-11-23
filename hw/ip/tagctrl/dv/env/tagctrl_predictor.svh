// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // The reference model of the tag controller: what the specification,
  // axi_cheri_tagcontroller/docs/tag_controller.adoc, says it returns on its two subordinate
  // ports, given the accesses seen so far. Every rule of the specification the environment checks
  // is here or in tagctrl_exp.svh, citing the lines it comes from as "tag_controller.adoc:<line>".
  //
  // For each completed access, tagctrl_scoreboard asks for an expectation (expect_cfg,
  // expect_tag), compares the access against it, then hands the access over (observe_cfg,
  // observe_tag). Where the specification leaves an answer open, the model widens what it accepts
  // and narrows it again from what the next status read shows.
  //
  // It models the baseline parameters of tagctrl_env_pkg, one access at a time: reset, region
  // register writes, one start with a valid configuration, and tagged accesses outside the tag
  // table, with one WUSER per chunk. Anything else is reported as not modelled. Assumed where the
  // specification is silent: a configuration access is a single 64-bit beat to the first 4 KiB,
  // and a configuration write updates only the bytes its strobes enable.
  class tagctrl_predictor extends uvm_object;
    `uvm_object_utils(tagctrl_predictor)

    // Whether tags are tracked
    typedef enum {StUnconfigured, StServing} state_e;

    // Registers
    local bit [63:0] covered_base, covered_top, tag_table_base;

    // Set by the first region register write after reset; until then the error field reads 0
    local bit region_written;

    // The last tag_table_top read since the region registers last changed
    local bit        ttt_seen;
    local bit [63:0] ttt_last;

    local state_e state;

    // The state bits of status (Serving, Zeroing, Flushing, Unconfigured) a read may show
    local bit [3:0] allowed_state;

    // The configuration taken by the start
    local bit [63:0] run_base, run_top, run_ttb;

    // Bytes written through the tagged subordinate; absent bytes are unknown
    local bit [7:0] mem[bit [63:0]];

    // Chunks whose tag is set, by address / ChunkBytes
    local bit tag_set[bit [63:0]];

    // Starts taken, and whether a status read has ever shown Zeroing
    local int unsigned starts_taken;
    local bit          zeroing_seen;

    function new(string name = "tagctrl_predictor");
      super.new(name);
      reset();
    endfunction

    // tag_controller.adoc:332-337: a start was taken and no status read has shown Zeroing
    function bit started_without_zeroing();
      return starts_taken > 0 && !zeroing_seen;
    endfunction

    // tag_controller.adoc:711-733: the init_* registers are 0, and init_start and init_locked are
    // clear, so the controller leaves reset Unconfigured and unlocked
    function void reset();
      covered_base   = '0;
      covered_top    = '0;
      tag_table_base = '0;
      region_written = 1'b0;
      ttt_seen       = 1'b0;
      state          = StUnconfigured;
      allowed_state  = 4'b1 << StatusUnconfigured;
      run_base       = '0;
      run_top        = '0;
      run_ttb        = '0;
      // Memory contents survive a reset of the DUT; its tags are cleared by the next start
      tag_set.delete();
    endfunction

    local function void not_modelled(string what);
      `uvm_fatal("tagctrl_predictor", {what, " is not modelled"})
    endfunction

    // The lowest and highest byte an access addresses
    local static function void access_bounds(axi_addr_t addr, bit [2:0] size, bit [7:0] len,
                                             bit [1:0] burst, output bit [63:0] lo,
                                             output bit [63:0] hi);
      lo = '1;
      hi = '0;
      for (int unsigned n = 0; n <= len; n++) begin
        bit [63:0]   beat_addr;
        int unsigned lower, upper;
        axi_beat_lanes(addr, size, len, burst, BusBytes, n, beat_addr, lower, upper);
        beat_addr = beat_addr / BusBytes * BusBytes;
        if (beat_addr + lower < lo) lo = beat_addr + lower;
        if (beat_addr + upper > hi) hi = beat_addr + upper;
      end
    endfunction

    // ------------------------------------------------------------------------------------------
    // Configuration subordinate
    // ------------------------------------------------------------------------------------------

    function tagctrl_cfg_exp expect_cfg(axi_mon_item item);
      tagctrl_cfg_exp    exp = tagctrl_cfg_exp::type_id::create("cfg_exp");
      axi_mon_write_item wr;
      exp.offset = item.get_addr();
      if ($cast(wr, item)) return exp;
      case (exp.offset)
        RegStatus: begin
          exp.is_status   = 1'b1;
          exp.states      = allowed_state;
          exp.check_error = !region_written;
        end
        RegTagTableTop: begin
          exp.check_value = expected_tag_table_top(exp.lo, exp.hi);
          exp.align       = TagStoreAlign;
        end
        default: begin
          exp.check_value = 1'b1;
          exp.lo          = expected_reg(exp.offset);
          exp.hi          = exp.lo;
        end
      endcase
      return exp;
    endfunction

    function void observe_cfg(axi_mon_item item);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      if ($cast(wr, item)) begin
        cfg_write(wr.m_awaddr[11:0], wr.m_wdata[0][63:0], wr.m_wstrb[0][7:0]);
      end else begin
        void'($cast(rd, item));
        cfg_read(rd.m_araddr[11:0], rd.m_rdata[0][63:0]);
      end
    endfunction

    // tag_controller.adoc:496-498: the most tag table space a covered range may need, 1/127 of it
    // or 128 bytes
    local static function bit [63:0] tag_table_bound(bit [63:0] base, bit [63:0] top);
      bit [63:0] range = top - base;
      bit [63:0] bound = (range + 126) / 127;
      if (range == 0) return 0;
      return (bound > 128) ? bound : 128;
    endfunction

    // A configuration no reading of the specification puts in error: covered_base and covered_top
    // 8 KiB aligned (tag_controller.adoc:470, 478) with the top not below the base, tag_table_base
    // 64-byte aligned (tag_controller.adoc:486), and a tag table that fits below the top of the
    // address space (error 2, tag_controller.adoc:380-382)
    local static function bit cfg_valid(bit [63:0] base, bit [63:0] top, bit [63:0] ttb);
      return top >= base && base % 8192 == 0 && top % 8192 == 0 && ttb % TagStoreAlign == 0 &&
             ttb + tag_table_bound(base, top) >= ttb;
    endfunction

    local function void cfg_write(bit [11:0] offset, bit [63:0] data, bit [7:0] strb);
      bit [63:0] mask;
      for (int i = 0; i < 8; i++) mask[8*i +: 8] = {8{strb[i]}};

      if (offset == RegControl) begin
        control_write(data & mask);
      end else if (offset inside {RegCoveredBase, RegCoveredTop, RegTagTableBase}) begin
        // tag_controller.adoc:469-470: a write while unlocked unconfigures
        case (offset)
          RegCoveredBase:  covered_base   = (covered_base & ~mask) | (data & mask);
          RegCoveredTop:   covered_top    = (covered_top & ~mask) | (data & mask);
          default:         tag_table_base = (tag_table_base & ~mask) | (data & mask);
        endcase
        region_written = 1'b1;
        ttt_seen       = 1'b0;
        state          = StUnconfigured;
        allowed_state  = 4'b1 << StatusUnconfigured;
      end
    endfunction

    // tag_controller.adoc:430-431: commands must be one-hot and reserved bits are ignored
    local function void control_write(bit [63:0] data);
      bit [63:0] cmd = data & CtrlCmdMask;
      if ($countones(cmd) != 1) return;
      if (cmd != CtrlStart) not_modelled($sformatf("Control command 0x%0h", cmd));
      start();
    endfunction

    // tag_controller.adoc:434-439: take the region registers, zero the root table, then serve with
    // every tag clear (tag_controller.adoc:111-115)
    local function void start();
      if (state != StUnconfigured) not_modelled("A start outside Unconfigured");
      if (!cfg_valid(covered_base, covered_top, tag_table_base)) begin
        not_modelled("A start with a configuration that may be in error");
      end
      run_base = covered_base;
      run_top  = covered_top;
      run_ttb  = tag_table_base;
      starts_taken++;
      tag_set.delete();
      state         = StServing;
      allowed_state = (4'b1 << StatusZeroing) | (4'b1 << StatusServing);
    endfunction

    // tag_controller.adoc:230-304: the value a read of any offset but status and tag_table_top
    // returns. Control is write-only and reads 0, the reserved space reads 0, and so does every
    // performance register with no counters enabled (tag_controller.adoc:519, 789-791).
    local function bit [63:0] expected_reg(bit [11:0] offset);
      case (offset)
        RegCoveredBase:  return covered_base;
        RegCoveredTop:   return covered_top;
        RegTagTableBase: return tag_table_base;
        default:         return 0;
      endcase
    endfunction

    // tag_controller.adoc:491-501: the range a read may return, which is the base for an empty
    // covered region. Returns 0 if it cannot be predicted.
    local function bit expected_tag_table_top(output bit [63:0] lo, output bit [63:0] hi);
      if (ttt_seen) begin
        // Computed from the region registers, so unchanged since the last read
        lo = ttt_last;
        hi = ttt_last;
      end else if (!cfg_valid(covered_base, covered_top, tag_table_base)) begin
        // Whether an error is already encountered when the registers are written, before a
        // start, is not specified
        return 1'b0;
      end else if (covered_top == covered_base) begin
        lo = tag_table_base;
        hi = tag_table_base;
      end else begin
        lo = tag_table_base;
        hi = tag_table_base + tag_table_bound(covered_base, covered_top);
      end
      return 1'b1;
    endfunction

    local function void cfg_read(bit [11:0] offset, logic [63:0] data);
      if ($isunknown(data)) return;
      if (offset == RegStatus) begin
        status_read(data);
      end else if (offset == RegTagTableTop) begin
        ttt_seen = 1'b1;
        ttt_last = data;
      end
    endfunction

    // A status read showing Serving, once allowed, settles the state
    local function void status_read(bit [63:0] data);
      bit [3:0] st = data[3:0];
      if (st[StatusZeroing]) zeroing_seen = 1'b1;
      if ($countones(st) == 1 && st[StatusServing] && allowed_state[StatusServing]) begin
        allowed_state = st;
      end
    endfunction

    // ------------------------------------------------------------------------------------------
    // Tagged subordinate
    // ------------------------------------------------------------------------------------------

    function tagctrl_tag_exp expect_tag(axi_mon_item item);
      tagctrl_tag_exp    exp = tagctrl_tag_exp::type_id::create("tag_exp");
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      bit [63:0]         lo, hi;
      bit                in_covered;

      exp.addr = item.get_addr();
      if ($cast(wr, item)) begin
        access_bounds(wr.m_awaddr, wr.m_awsize, wr.m_awlen, wr.m_awburst, lo, hi);
        check_tag_table(lo, hi);
        return exp;
      end
      void'($cast(rd, item));
      access_bounds(rd.m_araddr, rd.m_arsize, rd.m_arlen, rd.m_arburst, lo, hi);
      check_tag_table(lo, hi);
      in_covered = covered(lo);

      exp.beat_base = new[rd.m_arlen + 1];
      exp.lower     = new[rd.m_arlen + 1];
      exp.upper     = new[rd.m_arlen + 1];
      exp.data      = new[rd.m_arlen + 1];
      exp.known     = new[rd.m_arlen + 1];
      for (int unsigned n = 0; n <= rd.m_arlen; n++) begin
        bit [63:0] beat_addr;
        axi_beat_lanes(rd.m_araddr, rd.m_arsize, rd.m_arlen, rd.m_arburst, BusBytes, n,
                       beat_addr, exp.lower[n], exp.upper[n]);
        exp.beat_base[n] = beat_addr / BusBytes * BusBytes;
        exp.data[n]      = '0;
        exp.known[n]     = '0;
        for (int unsigned lane = exp.lower[n]; lane <= exp.upper[n]; lane++) begin
          bit [63:0] a     = exp.beat_base[n] + lane;
          bit [63:0] chunk = a / ChunkBytes;
          if (mem.exists(a)) begin
            exp.data[n][8*lane +: 8] = mem[a];
            exp.known[n][lane]       = 1'b1;
          end
          if (!exp.chunks.exists(chunk)) exp.chunks[chunk] = expected_tag(chunk, in_covered);
        end
      end
      return exp;
    endfunction

    function void observe_tag(axi_mon_item item);
      axi_mon_write_item wr;
      // Nothing reached memory unless the write answered OKAY
      if ($cast(wr, item) && wr.m_bresp === RespOkay) tag_write(wr);
    endfunction

    // tag_controller.adoc:122-125: while Serving, a request with any byte in the tag table gets a
    // bus error
    local function void check_tag_table(bit [63:0] lo, bit [63:0] hi);
      if (state == StUnconfigured || run_top == run_base) return;
      if (hi >= run_ttb && lo < run_ttb + tag_table_bound(run_base, run_top)) begin
        not_modelled($sformatf("An access to the tag table at 0x%0h", lo));
      end
    endfunction

    // Whether an access starting at lo lies in the covered region of the running configuration.
    // With a covered region aligned to 8 KiB, no access straddles its boundary
    // (tag_controller.adoc:118-120).
    local function bit covered(bit [63:0] lo);
      return lo >= run_base && lo < run_top;
    endfunction

    // The tag a read may return for a chunk. Tags read zero while Unconfigured and outside the
    // covered region (tag_controller.adoc:108-109, 127-131). A set tag is required only while
    // Serving.
    local function tagctrl_tag_exp::chunk_exp_t expected_tag(bit [63:0] chunk, bit in_covered);
      tagctrl_tag_exp::chunk_exp_t ce;
      ce.may_be_set   = 1'b0;
      ce.set_if_whole = 1'b0;
      if (state == StServing && in_covered && tag_set.exists(chunk)) begin
        ce.may_be_set   = 1'b1;
        ce.set_if_whole = 1'b1;
      end
      return ce;
    endfunction

    // A write that reached memory: its bytes, and the tags of the chunks it wrote. A write to any
    // part of a chunk sets its tag from WUSER (tag_controller.adoc:164-166). Tags are only taken
    // while Serving, and only inside the covered region (tag_controller.adoc:108-109, 127-134).
    local function void tag_write(axi_mon_write_item wr);
      // Per chunk written, the WUSER values its beats carried
      bit [1:0] chunk_users[bit [63:0]];

      foreach (wr.m_wdata[n]) begin
        bit [63:0]   beat_addr;
        int unsigned lower, upper;
        axi_beat_lanes(wr.m_awaddr, wr.m_awsize, wr.m_awlen, wr.m_awburst, BusBytes, n,
                       beat_addr, lower, upper);
        beat_addr = beat_addr / BusBytes * BusBytes;
        for (int unsigned lane = lower; lane <= upper; lane++) begin
          bit [63:0] a = beat_addr + lane;
          if (wr.m_wstrb[n][lane] !== 1'b1) continue;
          if (!chunk_users.exists(a / ChunkBytes)) chunk_users[a / ChunkBytes] = 2'b00;
          if ($isunknown(wr.m_wdata[n][8*lane +: 8])) mem.delete(a);
          else mem[a] = wr.m_wdata[n][8*lane +: 8];
          chunk_users[a / ChunkBytes][wr.m_wuser[n][0] === 1'b1] = 1'b1;
        end
      end

      if (state == StUnconfigured || !covered(wr.m_awaddr)) return;
      foreach (chunk_users[c]) begin
        if (chunk_users[c] == 2'b11) begin
          not_modelled($sformatf("Chunk 0x%0h written with differing WUSER", c * ChunkBytes));
        end
        if (chunk_users[c][1]) tag_set[c] = 1'b1;
        else tag_set.delete(c);
      end
    endfunction
  endclass
