// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitored AXI read transaction: the read address (AR) and the read data beats (R).
// Published on tx_ap once complete.

class axi_mon_read_item extends axi_mon_item;

  // Read address (AR)
  axi_id_t                       m_arid;
  axi_addr_t                     m_araddr;
  logic [AxiLenWidth-1:0]        m_arlen;
  logic [AxiSizeWidth-1:0]       m_arsize;
  logic [AxiBurstWidth-1:0]      m_arburst;
  logic                          m_arlock;
  logic [AxiCacheWidth-1:0]      m_arcache;
  logic [AxiProtWidth-1:0]       m_arprot;
  logic [AxiQosWidth-1:0]        m_arqos;
  logic [AxiRegionWidth-1:0]     m_arregion;
  logic [AxiMaxReqUserWidth-1:0] m_aruser;

  // Read data (R) — one entry per beat. RLAST is not stored: the monitor ends the burst on it,
  // so the beat count is m_rdata.size().
  axi_id_t                       m_rid;
  logic [AxiMaxDataWidth-1:0]    m_rdata[$];
  logic [AxiRespWidth-1:0]       m_rresp[$];
  logic [AxiMaxRUserWidth-1:0]   m_ruser[$];

  `uvm_object_utils_begin(axi_mon_read_item)
    // Read Address
    `uvm_field_int(m_arid, UVM_DEFAULT)
    `uvm_field_int(m_araddr, UVM_DEFAULT)
    `uvm_field_int(m_arlen, UVM_DEFAULT)
    `uvm_field_int(m_arsize, UVM_DEFAULT)
    `uvm_field_int(m_arburst, UVM_DEFAULT)
    `uvm_field_int(m_arlock, UVM_DEFAULT)
    `uvm_field_int(m_arcache, UVM_DEFAULT)
    `uvm_field_int(m_arprot, UVM_DEFAULT)
    `uvm_field_int(m_arqos, UVM_DEFAULT)
    `uvm_field_int(m_arregion, UVM_DEFAULT)
    `uvm_field_int(m_aruser, UVM_DEFAULT)

    // Read Data (Queues)
    `uvm_field_int(m_rid, UVM_DEFAULT)
    `uvm_field_queue_int(m_rdata, UVM_DEFAULT)
    `uvm_field_queue_int(m_rresp, UVM_DEFAULT)
    `uvm_field_queue_int(m_ruser, UVM_DEFAULT)
  `uvm_object_utils_end

  extern function new(string name = "");

  extern virtual function axi_id_t    get_id();
  extern virtual function axi_addr_t  get_addr();
  extern virtual function axi_dir_e   get_dir();
  extern virtual function string      convert2string();

endclass : axi_mon_read_item

function axi_mon_read_item::new(string name = "");
  super.new(name);
endfunction : new

function axi_id_t axi_mon_read_item::get_id();
  return m_arid;
endfunction : get_id

function axi_addr_t axi_mon_read_item::get_addr();
  return m_araddr;
endfunction : get_addr

function axi_dir_e axi_mon_read_item::get_dir();
  return AXI_READ;
endfunction : get_dir

function string axi_mon_read_item::convert2string();
  return $sformatf("READ id=%0h addr=%0h len=%0d size=%0d burst=%0d beats=%0d",
                   m_arid, m_araddr, m_arlen, m_arsize, m_arburst, m_rdata.size());
endfunction : convert2string
