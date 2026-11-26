// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // One access on the configuration or the tagged subordinate, run by tagctrl_access_seq
  class tagctrl_op extends uvm_object;
    `uvm_object_utils(tagctrl_op)

    rand tagctrl_port_e   port;
    rand bit              write;
    rand bit [AxiIdWidth-1:0] id;
    rand bit [63:0]       addr;
    rand bit [7:0]        len;
    rand bit [2:0]        size;
    rand burst_e          burst;

    // Per beat, with the byte at the beat's address least significant
    rand bit [63:0]       wdata[];
    rand bit [7:0]        wstrb[];
    rand bit              wuser[];

    // Read data of each beat once the access has completed, addressed byte least significant
    bit [63:0]            rdata[$];

    function new(string name = "tagctrl_op");
      super.new(name);
    endfunction

    constraint beats_c {
      wdata.size() == len + 1;
      wstrb.size() == len + 1;
      wuser.size() == len + 1;
    }

    // INCR bursts of up to 16 beats, every strobe set
    constraint axi_c {
      size <= $clog2(BusBytes);
      len < 16;
      burst == BurstIncr;
      ((addr[11:0] >> size) + len + 1) <= (13'h1000 >> size);
      foreach (wstrb[j]) wstrb[j] == 8'hff;
    }

    // The register map is accessed a whole 64-bit register at a time: how narrower accesses
    // behave is an open question of the specification.
    constraint cfg_c {
      port == PortCfg -> {
        len == 0;
        size == 3;
        addr < CfgSpaceBytes;
        addr[2:0] == 0;
        wuser[0] == 0;
      }
    }

    function string convert2string();
      return $sformatf("%s %s addr 0x%016h len %0d size %0d %s", port.name(),
                       write ? "write" : "read", addr, len, size, burst.name());
    endfunction
  endclass

  // A random access shaped by the knobs of a tagctrl_seq_cfg
  class tagctrl_knob_op extends tagctrl_op;
    `uvm_object_utils(tagctrl_knob_op)

    // Set before randomising
    tagctrl_seq_cfg cfg;

    function new(string name = "tagctrl_knob_op");
      super.new(name);
    endfunction

    constraint port_c {
      port dist {PortCfg := cfg.cfg_weight, PortTag := cfg.tag_weight};
      cfg.cfg_weight == 0 -> port == PortTag;
      cfg.tag_weight == 0 -> port == PortCfg;
    }

    constraint write_c {
      port == PortCfg -> write dist {1 := cfg.cfg_write_pct, 0 := 100 - cfg.cfg_write_pct};
      port == PortTag -> write dist {1 := cfg.tag_write_pct, 0 := 100 - cfg.tag_write_pct};
      port == PortCfg && cfg.cfg_write_pct == 0 -> !write;
      port == PortCfg && cfg.cfg_write_pct == 100 -> write;
      port == PortTag && cfg.tag_write_pct == 0 -> !write;
      port == PortTag && cfg.tag_write_pct == 100 -> write;
    }

    // Accesses on the configuration subordinate mostly go to the registers. Control writes carry
    // no command: the configuration steps issue the start.
    constraint cfg_addr_c {
      port == PortCfg -> {
        cfg.cfg_scope == CfgScopeAll -> addr dist {[0:RegTagTableTop] :/ 8,
                                                   [RegTagTableTop + 8:CfgSpaceBytes - 8] :/ 2};
        cfg.cfg_scope == CfgScopeRegion -> addr inside {RegCoveredBase, RegCoveredTop,
                                                        RegTagTableBase};
        cfg.cfg_scope == CfgScopeStatus -> addr == RegStatus;
        write && addr == RegControl -> (wdata[0] & CtrlCmdMask) == 0;
      }
    }

    // Unless region_any is set, a region register write puts back the value of the knobs
    constraint region_write_c {
      port == PortCfg && write && !cfg.region_any -> {
        addr == RegCoveredBase -> wdata[0] == cfg.covered_base;
        addr == RegCoveredTop -> wdata[0] == cfg.covered_top;
        addr == RegTagTableBase -> wdata[0] == cfg.tag_table_base;
      }
    }

    // Bursts of whole aligned chunks in the covered region, each chunk carrying one tag
    constraint tag_c {
      port == PortTag -> {
        addr - cfg.covered_base < cfg.covered_top - cfg.covered_base;
        size == $clog2(BusBytes);
        addr % ChunkBytes == 0;
        (len + 1) % (ChunkBytes / BusBytes) == 0;
        foreach (wuser[j]) {
          j % (ChunkBytes / BusBytes) != 0 -> wuser[j] == wuser[j - 1];
        }
      }
    }
  endclass
