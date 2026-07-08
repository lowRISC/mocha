// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A monitored AXI write transaction: the write address (AW), the write data beats (W)
// and the write response (B). Published on tx_ap once complete.

class axi_mon_write_item extends axi_mon_item;

  // Write address (AW)
  axi_id_t                        m_awid;
  axi_addr_t                      m_awaddr;
  logic [AxiLenWidth-1:0]         m_awlen;
  logic [AxiSizeWidth-1:0]        m_awsize;
  logic [AxiBurstWidth-1:0]       m_awburst;
  logic                           m_awlock;
  logic [AxiCacheWidth-1:0]       m_awcache;
  logic [AxiProtWidth-1:0]        m_awprot;
  logic [AxiQosWidth-1:0]         m_awqos;
  logic [AxiRegionWidth-1:0]      m_awregion;
  logic [AxiMaxReqUserWidth-1:0]  m_awuser;

  // Write data (W) — one entry per beat. WLAST is not stored: the monitor ends the burst on it,
  // so the beat count is m_wdata.size().
  logic [AxiMaxDataWidth-1:0]     m_wdata[$];
  logic [AxiMaxStrbWidth-1:0]     m_wstrb[$];
  logic [AxiMaxDataUserWidth-1:0] m_wuser[$];

  // Write response (B)
  axi_id_t                        m_bid;
  logic [AxiRespWidth-1:0]        m_bresp;
  logic [AxiMaxRespUserWidth-1:0] m_buser;

  `uvm_object_utils_begin(axi_mon_write_item)
    // Write Address
    `uvm_field_int(m_awid, UVM_DEFAULT)
    `uvm_field_int(m_awaddr, UVM_DEFAULT)
    `uvm_field_int(m_awlen, UVM_DEFAULT)
    `uvm_field_int(m_awsize, UVM_DEFAULT)
    `uvm_field_int(m_awburst, UVM_DEFAULT)
    `uvm_field_int(m_awlock, UVM_DEFAULT)
    `uvm_field_int(m_awcache, UVM_DEFAULT)
    `uvm_field_int(m_awprot, UVM_DEFAULT)
    `uvm_field_int(m_awqos, UVM_DEFAULT)
    `uvm_field_int(m_awregion, UVM_DEFAULT)
    `uvm_field_int(m_awuser, UVM_DEFAULT)

    // Write Data (Queues)
    `uvm_field_queue_int(m_wdata, UVM_DEFAULT)
    `uvm_field_queue_int(m_wstrb, UVM_DEFAULT)
    `uvm_field_queue_int(m_wuser, UVM_DEFAULT)

    // Write Response
    `uvm_field_int(m_bid, UVM_DEFAULT)
    `uvm_field_int(m_bresp, UVM_DEFAULT)
    `uvm_field_int(m_buser, UVM_DEFAULT)
  `uvm_object_utils_end

  extern function new(string name = "");

  extern virtual function axi_id_t    get_id();
  extern virtual function axi_addr_t  get_addr();
  extern virtual function axi_dir_e   get_dir();
  extern virtual function string      convert2string();

endclass : axi_mon_write_item

function axi_mon_write_item::new(string name = "");
  super.new(name);
endfunction : new

function axi_id_t axi_mon_write_item::get_id();
  return m_awid;
endfunction : get_id

function axi_addr_t axi_mon_write_item::get_addr();
  return m_awaddr;
endfunction : get_addr

function axi_dir_e axi_mon_write_item::get_dir();
  return AXI_WRITE;
endfunction : get_dir

function string axi_mon_write_item::convert2string();
  return $sformatf("WRITE id=%0h addr=%0h len=%0d size=%0d burst=%0d beats=%0d m_bresp=%0h",
                   m_awid, m_awaddr, m_awlen, m_awsize, m_awburst, m_wdata.size(), m_bresp);
endfunction : convert2string
