// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Step: walk the register map in offset order, taking the registers from the register model.
  // WalkRead reads each register, then the performance registers at the offsets both the
  // register table and the register sections give them. WalkWriteRead reads, writes and reads
  // again each register: control writes carry no command, and the region registers are written
  // with the values below.
  class tagctrl_cfg_walk_seq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_cfg_walk_seq)

    localparam bit [11:0] PerfOffsets[6] = '{'heb0, 'hec0, 'hed0, 'hee0, 'hf00, 'hff8};

    // Set before starting
    tagctrl_walk_e walk;
    bit [63:0]     covered_base;
    bit [63:0]     covered_top;
    bit [63:0]     tag_table_base;

    function new(string name = "tagctrl_cfg_walk_seq");
      super.new(name);
    endfunction

    task body();
      uvm_reg    regs[$];
      bit [63:0] rdata;

      p_sequencer.cfg.ral.get_registers(regs);
      regs.sort() with (item.get_offset());
      foreach (regs[i]) begin
        bit [11:0] offset = regs[i].get_offset();
        cfg_access(1'b0, offset, , rdata);
        if (walk == WalkWriteRead) begin
          cfg_access(1'b1, offset, write_value(offset), rdata);
          cfg_access(1'b0, offset, , rdata);
        end
      end
      if (walk == WalkRead) begin
        foreach (PerfOffsets[i]) cfg_access(1'b0, PerfOffsets[i], , rdata);
      end
    endtask

    local function bit [63:0] write_value(bit [11:0] offset);
      bit [63:0] value = {$urandom, $urandom};
      case (offset)
        RegControl:      return value & ~CtrlCmdMask;
        RegCoveredBase:  return covered_base;
        RegCoveredTop:   return covered_top;
        RegTagTableBase: return tag_table_base;
        default:         return value;
      endcase
    endfunction
  endclass
