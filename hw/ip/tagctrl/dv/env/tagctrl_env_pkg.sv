// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// UVM environment for the tag controller (axi_tagctrl_top), checked against its specification,
// docs/tag_controller.adoc in the upstream repository, driving the configuration and tagged
// subordinates. Each block lives in its own file and is `included here in dependency order:
//
//   tagctrl_env_cfg.svh            -- scoreboard switches, register model
//   tagctrl_exp.svh                -- what the predictor accepts for one access, and the compare
//   tagctrl_predictor.svh          -- the reference model: every rule of the specification
//   tagctrl_scoreboard.svh         -- compares the monitored accesses against the predictor
//   tagctrl_virtual_sequencer.svh  -- the two manager sequencers and the clock and reset
//   tagctrl_env.svh                -- the agents, the scoreboard and the register map

package tagctrl_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import axi_agent_pkg::*;
  import tagctrl_ral_pkg::*;

  // The baseline configuration of the vPlan: the specification's default widths and geometry,
  // with init_start, init_locked, allow_resume and allow_flush_when_locked clear and no
  // performance counters.
  localparam int unsigned AxiIdWidth     = 6;
  localparam int unsigned AxiAddrWidth   = 64;
  localparam int unsigned AxiDataWidth   = 64;
  localparam int unsigned AxiUserWidth   = 1;
  localparam int unsigned BusBytes       = AxiDataWidth / 8;
  localparam int unsigned ChunkBytes     = 16;
  localparam int unsigned GroupingFactor = 256;
  localparam int unsigned CoveredAlign   = 4096;
  localparam int unsigned TagStoreAlign  = 64;
  localparam int unsigned PerfCounters   = 0;

  // The register map takes 4 KiB of the configuration subordinate
  localparam bit [63:0] CfgSpaceBytes = 64'h1000;

  typedef enum bit [11:0] {
    RegStatus       = 12'h000,
    RegControl      = 12'h008,
    RegCoveredBase  = 12'h010,
    RegCoveredTop   = 12'h018,
    RegTagTableBase = 12'h020,
    RegTagTableTop  = 12'h028
  } tagctrl_reg_e;

  // status fields
  localparam int unsigned StatusServing      = 0;
  localparam int unsigned StatusZeroing      = 1;
  localparam int unsigned StatusFlushing     = 2;
  localparam int unsigned StatusUnconfigured = 3;
  localparam int unsigned StatusLocked       = 4;
  localparam bit [63:0]   StatusErrorMask    = 64'h00ff_0000;
  localparam bit [63:0]   StatusReservedMask = 64'hffff_ffff_ff00_ffe0;

  // control commands
  localparam bit [63:0] CtrlStart  = 64'h0000_0001;
  localparam bit [63:0] CtrlResume = 64'h0000_0100;
  localparam bit [63:0] CtrlStop   = 64'h0001_0000;
  localparam bit [63:0] CtrlLock   = 64'h0100_0000;
  localparam bit [63:0] CtrlCmdMask = CtrlStart | CtrlResume | CtrlStop | CtrlLock;

  typedef enum bit {PortCfg, PortTag} tagctrl_port_e;

  `include "tagctrl_env_cfg.svh"
  `include "tagctrl_exp.svh"
  `include "tagctrl_predictor.svh"
  `include "tagctrl_scoreboard.svh"
  `include "tagctrl_virtual_sequencer.svh"
  `include "tagctrl_env.svh"
endpackage
