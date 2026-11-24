// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Random legal request within the link's address window. Call set_bus, configure burst knobs, then
// randomize.

class axi_agent_rand_req extends axi_txn_request_item;
  `uvm_object_utils(axi_agent_rand_req)

  // The bus and the window, from set_bus
  int unsigned              m_id_width;
  int unsigned              m_user_width;
  int unsigned              m_bus_size;
  bit                       m_is_lite;
  bit [AxiMaxAddrWidth-1:0] m_addr_lo;
  bit [AxiMaxAddrWidth-1:0] m_addr_hi;

  // Which bursts to pick
  bit          m_allow_fixed   = 1'b1;
  bit          m_allow_wrap    = 1'b1;
  bit          m_allow_lock    = 1'b0;
  bit          m_fixed_aligned = 1'b0;
  int unsigned m_max_len       = 15;

  // Percentage of INCR bursts that end on the last byte of a 4KB page
  int unsigned m_to_boundary_pct = 15;
  rand bit     m_to_boundary;

  // Percentage of bursts longer than 16 beats, up to m_max_len + 1. These must be INCR (AMBA AXI
  // H.c A3.4.1). Other bursts have at most 16 beats.
  int unsigned m_long_pct = 0;
  rand bit     m_long;

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods

  extern function void set_bus(axi_agent_env_cfg cfg);

  // Return the burst's byte range [lo, hi] from its transaction container, starting at the address
  // for unaligned INCR (AMBA AXI H.c A3.4.1)
  extern function void get_range(output bit [AxiMaxAddrWidth-1:0] lo,
                                 output bit [AxiMaxAddrWidth-1:0] hi);

  extern constraint bus_c;
  extern constraint shape_c;
endclass : axi_agent_rand_req


function axi_agent_rand_req::new(string name = "");
  super.new(name);
endfunction : new

function void axi_agent_rand_req::set_bus(axi_agent_env_cfg cfg);
  m_id_width   = cfg.m_id_width;
  m_user_width = cfg.m_user_width;
  m_bus_size   = $clog2(cfg.m_data_width / 8);
  m_is_lite    = cfg.m_is_lite;
  m_addr_lo    = cfg.m_link.m_addr_lo;
  m_addr_hi    = cfg.m_link.m_addr_hi;
  m_allow_wrap = cfg.m_link.m_allows_wrap;
  if (!cfg.m_link.m_allows_unaligned_fixed) begin
    m_fixed_aligned = 1'b1;
  end
endfunction : set_bus

function void axi_agent_rand_req::get_range(output bit [AxiMaxAddrWidth-1:0] lo,
                                            output bit [AxiMaxAddrWidth-1:0] hi);
  int unsigned nbytes = 1 << m_size;
  int unsigned total = nbytes * (m_len + 1);

  case (m_burst)
    BurstFixed: begin
      lo = m_addr;
      hi = (m_addr / nbytes) * nbytes + nbytes - 1;
    end
    BurstWrap: begin
      lo = (m_addr / total) * total;
      hi = lo + total - 1;
    end
    default: begin
      lo = m_addr;
      hi = (m_addr / nbytes) * nbytes + total - 1;
    end
  endcase
endfunction : get_range

constraint axi_agent_rand_req::bus_c {
  (m_id >> m_id_width) == 0;
  (m_user >> m_user_width) == 0;
  m_size <= m_bus_size;
  m_addr >= m_addr_lo;
  m_addr <= m_addr_hi;
  m_burst == BurstIncr -> ((m_addr >> m_size) + m_len + 1) << m_size <= m_addr_hi + 1;
  // AXI4-Lite uses one full-width transfer with defaults for omitted signals (H.c B1.1.1, A9.3)
  m_is_lite -> (m_len == 0 && m_size == m_bus_size && m_burst == BurstIncr && m_lock == 0 &&
                m_cache == 0);
}

constraint axi_agent_rand_req::shape_c {
  m_len <= m_max_len;
  m_long dist {1 := m_long_pct, 0 := 100 - m_long_pct};
  m_long -> (m_burst == BurstIncr && m_len > 15);
  !m_long -> m_len <= 15;
  solve m_long before m_burst, m_len;
  !m_allow_fixed -> m_burst != BurstFixed;
  !m_allow_wrap -> m_burst != BurstWrap;
  !m_allow_lock -> m_lock == 0;
  (m_fixed_aligned && m_burst == BurstFixed) -> (m_addr & ((1 << m_size) - 1)) == 0;
  m_to_boundary dist {1 := m_to_boundary_pct, 0 := 100 - m_to_boundary_pct};
  m_to_boundary -> (m_burst == BurstIncr &&
                    ((((m_addr >> m_size) + m_len + 1) << m_size) % 4096) == 0);
  solve m_to_boundary before m_burst;
}
