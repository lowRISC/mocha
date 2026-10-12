// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// An extremely simple uvm_reg_adapter that wraps a uvm_reg_op in an axi_reg_op_item or copies the
// response fields back from that item. It also converts the axi_mon_item objects published by the
// monitor of either agent, so a uvm_reg_predictor can use it on either side of the bus.

class axi_reg_adapter extends uvm_reg_adapter;
  `uvm_object_utils(axi_reg_adapter)

  // Data bus width in bytes for monitored byte-lane placement; set with set_bus_bytes()
  local int unsigned m_bus_bytes = AxiMaxStrbWidth;

  // With exclusive support, OKAY on an exclusive write means no memory update and UVM_NOT_OK.
  // Without it, OKAY means the write succeeded (AMBA AXI H.c A7.2.3, A7.2.5). Set with
  // set_exclusive_support().
  local bit m_exclusive_support = 1'b0;

  extern function new(string name="");
  extern function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
  extern function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);

  extern function void set_bus_bytes(int unsigned bus_bytes);

  extern function void set_exclusive_support(bit exclusive_support);

  // Convert axi_reg_op_item responses from the register layering sequence for reg_map
  extern local function void bus2reg_reg_op(axi_reg_op_item bus_item, ref uvm_reg_bus_op rw);

  // Convert axi_mon_item's first-beat bytes for uvm_reg_predictor. Bursts return UVM_NOT_OK because
  // register accesses are single transfers.
  extern local function void bus2reg_txn(axi_mon_item bus_item, ref uvm_reg_bus_op rw);
endclass

function axi_reg_adapter::new(string name="");
  super.new(name);
  supports_byte_enable = 1;

  // Setting this to true means that the "bus driver" (here, axi_mgr_register_layer_vseq) sends a
  // response to the sequencer.
  provides_responses   = 1;
endfunction

function uvm_sequence_item axi_reg_adapter::reg2bus(const ref uvm_reg_bus_op rw);
  axi_reg_op_item bus_item = axi_reg_op_item::type_id::create("bus_item");

  // Take a copy of the uvm_reg_bus_op (which will be a deep copy because uvm_reg_bus_op is a
  // struct)
  bus_item.m_rw = rw;

  return bus_item;
endfunction

function void axi_reg_adapter::bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
  axi_reg_op_item reg_op_item;
  axi_mon_item    mon_item;

  if ($cast(reg_op_item, bus_item)) begin
    bus2reg_reg_op(reg_op_item, rw);
  end else if ($cast(mon_item, bus_item)) begin
    bus2reg_txn(mon_item, rw);
  end else begin
    `uvm_fatal("bus2reg", "bus_item is neither an axi_reg_op_item nor an axi_mon_item")
  end
endfunction

function void axi_reg_adapter::set_bus_bytes(int unsigned bus_bytes);
  m_bus_bytes = bus_bytes;
endfunction: set_bus_bytes

function void axi_reg_adapter::set_exclusive_support(bit exclusive_support);
  m_exclusive_support = exclusive_support;
endfunction: set_exclusive_support

function void axi_reg_adapter::bus2reg_reg_op(axi_reg_op_item bus_item, ref uvm_reg_bus_op rw);
  rw.kind   = bus_item.m_rw.kind;
  rw.addr   = bus_item.m_rw.addr;
  rw.data   = bus_item.m_rw.data;
  rw.status = bus_item.m_rw.status;
endfunction: bus2reg_reg_op

function void axi_reg_adapter::bus2reg_txn(axi_mon_item bus_item, ref uvm_reg_bus_op rw);
  axi_mon_write_item write_item;
  axi_mon_read_item  read_item;
  int unsigned       lane = bus_item.get_addr() % m_bus_bytes;

  // The first beat carries the bytes from the address to the end of its AxSIZE container (AMBA AXI
  // H.c A3.4.1, A3.4.4)
  int unsigned              nbytes;
  bit [AxiMaxStrbWidth-1:0] strb_mask;
  bit [AxiMaxDataWidth-1:0] data_mask;

  rw.addr = bus_item.get_addr();
  if ($cast(write_item, bus_item)) begin
    bit single = (write_item.m_awlen == 0);
    bit failed_excl = (m_exclusive_support && write_item.m_awlock === 1'b1 &&
                       write_item.m_bresp == RespOkay);

    nbytes     = (1 << write_item.m_awsize) - (rw.addr % (1 << write_item.m_awsize));
    strb_mask  = (AxiMaxStrbWidth'(1) << nbytes) - 1;
    data_mask  = (AxiMaxDataWidth'(1) << (8 * nbytes)) - 1;
    rw.kind    = UVM_WRITE;
    rw.n_bits  = 8 * nbytes;
    rw.byte_en = (write_item.m_wstrb.size() > 0) ?
                 ((write_item.m_wstrb[0] >> lane) & strb_mask) : '0;
    rw.data    = (write_item.m_wdata.size() > 0) ?
                 ((write_item.m_wdata[0] >> (8 * lane)) & data_mask) : '0;
    rw.status  = (single && !failed_excl && write_item.m_bresp inside {RespOkay, RespExOkay}) ?
                 UVM_IS_OK : UVM_NOT_OK;
  end else if ($cast(read_item, bus_item)) begin
    bit single = (read_item.m_arlen == 0);

    nbytes     = (1 << read_item.m_arsize) - (rw.addr % (1 << read_item.m_arsize));
    strb_mask  = (AxiMaxStrbWidth'(1) << nbytes) - 1;
    data_mask  = (AxiMaxDataWidth'(1) << (8 * nbytes)) - 1;
    rw.kind    = UVM_READ;
    rw.n_bits  = 8 * nbytes;
    rw.byte_en = strb_mask;
    rw.data    = (read_item.m_rdata.size() > 0) ?
                 ((read_item.m_rdata[0] >> (8 * lane)) & data_mask) : '0;
    rw.status  = (single && read_item.m_rresp.size() > 0 &&
                  read_item.m_rresp[0] inside {RespOkay, RespExOkay}) ? UVM_IS_OK : UVM_NOT_OK;
  end else begin
    `uvm_fatal("bus2reg", "bus_item is neither an axi_mon_write_item nor an axi_mon_read_item")
  end
endfunction: bus2reg_txn
