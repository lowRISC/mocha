// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Map m_lo through m_hi. Unwritten mapped bytes return mapped_mem_default(addr), and unmapped
// writes are dropped. Override the mem_model byte methods used by the subordinate.

class axi_agent_mapped_mem extends axi_mem_model_t;
  `uvm_object_utils(axi_agent_mapped_mem)

  // The mapped bytes
  bit [AxiMaxAddrWidth-1:0] m_lo;
  bit [AxiMaxAddrWidth-1:0] m_hi;

  // The writes that were dropped because they fell outside the map
  int unsigned m_dropped_writes;

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods
  extern virtual function bit addr_is_mapped(mem_addr_t addr);
  extern virtual function bit [7:0] read_byte(mem_addr_t addr);
  extern virtual function void write_byte(mem_addr_t addr, logic [7:0] data);
endclass : axi_agent_mapped_mem


function axi_agent_mapped_mem::new(string name = "");
  super.new(name);
endfunction : new

function bit axi_agent_mapped_mem::addr_is_mapped(mem_addr_t addr);
  return addr >= m_lo && addr <= m_hi;
endfunction : addr_is_mapped

function bit [7:0] axi_agent_mapped_mem::read_byte(mem_addr_t addr);
  if (!addr_is_mapped(addr)) begin
    `uvm_error(get_name(), $sformatf("Read from unmapped address 0x%0h.", addr))
    return '0;
  end
  if (addr_exists(addr)) begin
    return super.read_byte(addr);
  end
  return mapped_mem_default(addr);
endfunction : read_byte

function void axi_agent_mapped_mem::write_byte(mem_addr_t addr, logic [7:0] data);
  if (!addr_is_mapped(addr)) begin
    m_dropped_writes++;
    return;
  end
  super.write_byte(addr, data);
endfunction : write_byte
