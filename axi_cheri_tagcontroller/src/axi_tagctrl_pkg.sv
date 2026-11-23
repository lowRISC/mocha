// Copyright 2023 Bruno Sá and Zero-Day Labs.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Bruno Sá <bruno.vilaca.sa@gmail.com>
// Date:   07.12.2023

/// Contains the configuration and internal messages structs of the `axi_tagctrl`.
/// Parameter contained in this package are for fine grain configuration of the modules.
/// They can be changed to adapt the cache to a specific design for optimal performance.
package axi_tagctrl_pkg;
  /// Version parameter, can be read out from configuration port.
  ///
  /// This is ASCII encoded after the semantic versioning: `vAA.BB.C`
  parameter logic [63:0] AxiTagCtrlVersion = 64'h7630_302E_3030_2E31;
  parameter logic [3:0] AxReqId = 4'b1011;

  /// Tag Controller configuration struct.
  typedef struct packed {
    /// AXI4+ATOP ID width of the slave port from CPU side
    int unsigned AxiIdWidth;
    /// AXI4+ATOP address width of the slave port from CPU side
    int unsigned AxiAddrWidth;
    /// AXI4+ATOP data width of the slave port from CPU side
    int unsigned AxiDataWidth;
    /// Capability size in memory
    int unsigned CapSize;
    /// Tag controller write FIFO depth
    int unsigned TagWFifoDepth;
    /// Tag controller AX FIFO depth
    int unsigned TagAXFifoDepth;
    /// Tag controller read FIFO from memory depth
    int unsigned TagRFifoDepth;
  } tagctrl_cfg_t;

  typedef struct packed {
    logic alloc;
    logic retire_wait;
    logic retire_wait_root;
    logic retire_wait_leaf;
    logic retire_root_zero;
    logic retire_tags_zero;
  } tag_lookup_engine_table_lookups_read_events_t;

  typedef struct packed {
    logic alloc;
    logic alloc_tags_zero;
    logic retire_wait;
    logic retire_wait_root;
    logic retire_wait_leaf;
    logic retire_root_zero;
  } tag_lookup_engine_table_lookups_write_events_t;

  typedef struct packed {
    tag_lookup_engine_table_lookups_read_events_t read_events;
    tag_lookup_engine_table_lookups_write_events_t write_events;
  } tag_lookup_engine_table_lookups_events_t;

  typedef struct packed {
    logic cache_write_miss;
    logic cache_read_miss;
    logic uncached_req;
    logic cmo_req;
    logic write_req;
    logic read_req;
    logic prefetch_req;
    logic req_on_hold;
    logic rtab_rollback;
    logic stall_refill;
    logic stall;
  } hpdcache_events_t;

  typedef struct packed {
    tag_lookup_engine_table_lookups_events_t lookup_events;
    hpdcache_events_t root_cache_events;
    hpdcache_events_t leaf_cache_events;
  } tag_lookup_engine_events_t;

  typedef struct packed {
    logic state_unconfigured;
    logic state_preflushing;
    logic state_flushing;
    logic state_prezeroing;
    logic state_zeroing;
    logic state_serving;
  } tagctrl_cfg_events_t;

  typedef struct packed {
    tag_lookup_engine_events_t lookup_engine_events;
    tagctrl_cfg_events_t config_events;
  } tagctrl_events_t;

  function automatic logic [63:0] get_perf_event(tagctrl_events_t events, logic[7:0] select);
    automatic tagctrl_cfg_events_t cfg_evts = events.config_events;
    automatic tag_lookup_engine_table_lookups_read_events_t read_evts = events.lookup_engine_events.lookup_events.read_events;
    automatic tag_lookup_engine_table_lookups_write_events_t write_evts = events.lookup_engine_events.lookup_events.write_events;
    automatic hpdcache_events_t root_cache_evts = events.lookup_engine_events.root_cache_events;
    automatic hpdcache_events_t leaf_cache_evts = events.lookup_engine_events.leaf_cache_events;
    case (select)
      // Zero
      8'h00: return 64'h0;
      // One
      8'h01: return 64'h1;
      // New tag read req
      8'h10: return {63'h0, read_evts.alloc};
      // New tag write req
      8'h11: return {63'h0, write_evts.alloc};
      // New tag any req
      8'h12: return {62'h0, read_evts.alloc + write_evts.alloc};
      // Tag read blocked
      8'h13: return {63'h0, read_evts.retire_wait};
      // Tag write blocked
      8'h14: return {63'h0, write_evts.retire_wait};
      // Tag any blocked
      8'h15: return {63'h0, read_evts.retire_wait | write_evts.retire_wait};
      // Tag read blocked on root (possibly also leaf)
      8'h16: return {63'h0, read_evts.retire_wait_root};
      // Tag read blocked on leaf (possibly also root)
      8'h17: return {63'h0, read_evts.retire_wait_leaf};
      // Tag write blocked on root (possibly also leaf)
      8'h18: return {63'h0, write_evts.retire_wait_root};
      // Tag write blocked on leaf (possibly also root)
      8'h19: return {63'h0, write_evts.retire_wait_leaf};
      // Tag any blocked on root
      8'h1a: return {63'h0, read_evts.retire_wait_root | write_evts.retire_wait_root};
      // Tag any blocked on leaf
      8'h1b: return {63'h0, read_evts.retire_wait_leaf | write_evts.retire_wait_leaf};
      // Read gave zero tags
      8'h1c: return {63'h0, read_evts.retire_tags_zero};
      // Write had zero tags
      8'h1d: return {63'h0, write_evts.alloc_tags_zero};
      // Read/write zero tags
      8'h1e: return {62'h0, read_evts.retire_tags_zero + write_evts.alloc_tags_zero};
      // Read root zero
      8'h1f: return {63'h0, read_evts.retire_root_zero};
      // Write root zero
      8'h20: return {63'h0, write_evts.retire_root_zero};
      // Read/write root zero
      8'h21: return {62'h0, write_evts.retire_root_zero + read_evts.retire_root_zero};
      // Root HPDCache
      8'h40: return {63'h0, root_cache_evts.cache_write_miss};
      8'h41: return {63'h0, root_cache_evts.cache_read_miss};
      8'h42: return {63'h0, root_cache_evts.uncached_req};
      8'h43: return {63'h0, root_cache_evts.cmo_req};
      8'h44: return {63'h0, root_cache_evts.write_req};
      8'h45: return {63'h0, root_cache_evts.read_req};
      8'h46: return {63'h0, root_cache_evts.prefetch_req};
      8'h47: return {63'h0, root_cache_evts.req_on_hold};
      8'h48: return {63'h0, root_cache_evts.rtab_rollback};
      8'h49: return {63'h0, root_cache_evts.stall_refill};
      8'h4a: return {63'h0, root_cache_evts.stall};
      // Leaf HPDCache
      8'h50: return {63'h0, leaf_cache_evts.cache_write_miss};
      8'h51: return {63'h0, leaf_cache_evts.cache_read_miss};
      8'h52: return {63'h0, leaf_cache_evts.uncached_req};
      8'h53: return {63'h0, leaf_cache_evts.cmo_req};
      8'h54: return {63'h0, leaf_cache_evts.write_req};
      8'h55: return {63'h0, leaf_cache_evts.read_req};
      8'h56: return {63'h0, leaf_cache_evts.prefetch_req};
      8'h57: return {63'h0, leaf_cache_evts.req_on_hold};
      8'h58: return {63'h0, leaf_cache_evts.rtab_rollback};
      8'h59: return {63'h0, leaf_cache_evts.stall_refill};
      8'h5a: return {63'h0, leaf_cache_evts.stall};
      // Unconfigured
      8'hf0: return {63'h0, cfg_evts.state_unconfigured};
      // Preflushing
      8'hf1: return {63'h0, cfg_evts.state_preflushing};
      // Flushing
      8'hf2: return {63'h0, cfg_evts.state_flushing};
      // Prezeroing
      8'hf3: return {63'h0, cfg_evts.state_prezeroing};
      // Zeroing
      8'hf4: return {63'h0, cfg_evts.state_zeroing};
      // Serving
      8'hf5: return {63'h0, cfg_evts.state_serving};
      default: return 64'h0;
    endcase
  endfunction

endpackage
