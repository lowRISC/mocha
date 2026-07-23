// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Passive AXI transaction monitor. Snoops the five axi_*_if mon_cb clocking
// blocks and rebuilds whole transactions: AW+W are paired in AW order, B/R are
// matched to their request by ID. Per-channel items go out on aw/w/ar/r_ap;
// fully merged transactions on tx_ap (write completed at B, read completed at RLAST).
// Interfaces come from axi_agent_cfg.

class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)

  local axi_agent_cfg m_cfg;

  local virtual axi_write_request_if  m_aw_vif;
  local virtual axi_write_data_if     m_w_vif;
  local virtual axi_write_response_if m_b_vif;
  local virtual axi_read_request_if   m_ar_vif;
  local virtual axi_read_data_if      m_r_vif;
  local virtual clk_rst_if            m_clk_rst_vif;   // shared ACLK/ARESETn

  uvm_analysis_port #(axi_mon_item) aw_ap;
  uvm_analysis_port #(axi_mon_item) w_ap;
  uvm_analysis_port #(axi_mon_item) ar_ap;
  uvm_analysis_port #(axi_mon_item) r_ap;
  uvm_analysis_port #(axi_mon_item) tx_ap;

  // Write requests/data awaiting their counterpart on the other write channel.
  protected axi_mon_write_item aw_pending_q[$];
  protected axi_mon_write_item w_pending_q[$];

  // Outstanding (merged) requests awaiting their response, keyed by AXI ID.
  protected axi_mon_write_item write_q_by_id [bit [31:0]][$];
  protected axi_mon_read_item  read_q_by_id  [bit [31:0]][$];

  extern function new(string name, uvm_component parent);
  extern function void set_cfg(axi_agent_cfg cfg);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  // True when no requests are awaiting their response (no in-flight transactions).
  extern function bit is_idle();
  // Block until is_idle(), polling once per ACLK.
  extern task wait_for_idle();

  extern protected function void cleanup_queues();
  extern protected task collect_aw_channel();
  extern protected task collect_w_channel();
  extern protected task collect_b_channel();
  extern protected task collect_ar_channel();
  extern protected task collect_r_channel();

  // Return a copy of req with the AW attributes from aw_item merged in.
  extern protected function axi_mon_write_item merge_aw(axi_mon_write_item req,
                                                        axi_mon_write_item aw_item);
endclass : axi_monitor

function axi_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
  aw_ap = new("aw_ap", this);
  w_ap  = new("w_ap", this);
  ar_ap = new("ar_ap", this);
  r_ap  = new("r_ap", this);
  tx_ap = new("tx_ap", this);
endfunction : new

function void axi_monitor::set_cfg(axi_agent_cfg cfg);
  if (m_cfg != null) `uvm_fatal(get_full_name(), "Cannot set cfg: m_cfg is already non-null.")
  m_cfg = cfg;
endfunction : set_cfg

function void axi_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);

  if (m_cfg == null && !uvm_config_db#(axi_agent_cfg)::get(this, "", "cfg", m_cfg)) begin
    `uvm_fatal(get_full_name(), "failed to get cfg object from uvm_config_db")
  end

  m_aw_vif = m_cfg.write_request_vif;
  m_w_vif  = m_cfg.write_data_vif;
  m_b_vif  = m_cfg.write_response_vif;
  m_ar_vif = m_cfg.read_request_vif;
  m_r_vif  = m_cfg.read_data_vif;
  m_clk_rst_vif = m_cfg.clk_rst_vif;
endfunction : build_phase

task axi_monitor::run_phase(uvm_phase phase);
  forever begin
    wait (m_clk_rst_vif.rst_n === 1'b1);

    fork : isolation_fork
      begin
        fork
          wait (m_clk_rst_vif.rst_n === 1'b0);

          collect_aw_channel();
          collect_w_channel();
          collect_b_channel();
          collect_ar_channel();
          collect_r_channel();
        join_any

        disable fork;
      end
    join

    cleanup_queues();
  end
endtask : run_phase

function bit axi_monitor::is_idle();
  if (aw_pending_q.size() != 0) return 1'b0;
  if (w_pending_q.size()  != 0) return 1'b0;
  foreach (write_q_by_id[id]) if (write_q_by_id[id].size() != 0) return 1'b0;
  foreach (read_q_by_id[id])  if (read_q_by_id[id].size()  != 0) return 1'b0;
  return 1'b1;
endfunction : is_idle

task axi_monitor::wait_for_idle();
  while (!is_idle()) m_clk_rst_vif.wait_clks(1);
endtask : wait_for_idle

function void axi_monitor::cleanup_queues();
  aw_pending_q.delete();
  w_pending_q.delete();
  write_q_by_id.delete();
  read_q_by_id.delete();
endfunction : cleanup_queues

task axi_monitor::collect_aw_channel();
  forever begin
    @(m_aw_vif.mon_cb);
    if (m_aw_vif.mon_cb.awvalid && m_aw_vif.mon_cb.awready) begin
      axi_mon_write_item tr = axi_mon_write_item::type_id::create("aw_tr");

      tr.awid     = m_aw_vif.mon_cb.awid;
      tr.awaddr   = m_aw_vif.mon_cb.awaddr;
      tr.awlen    = m_aw_vif.mon_cb.awlen;
      tr.awsize   = m_aw_vif.mon_cb.awsize;
      tr.awburst  = m_aw_vif.mon_cb.awburst;
      tr.awlock   = m_aw_vif.mon_cb.awlock;
      tr.awcache  = m_aw_vif.mon_cb.awcache;
      tr.awprot   = m_aw_vif.mon_cb.awprot;
      tr.awqos    = m_aw_vif.mon_cb.awqos;
      tr.awregion = m_aw_vif.mon_cb.awregion;
      tr.awuser   = m_aw_vif.mon_cb.awuser;

      if (w_pending_q.size() > 0) begin
        axi_mon_write_item w_tr = w_pending_q.pop_front();
        write_q_by_id[tr.awid].push_back(merge_aw(w_tr, tr));
      end else begin
        aw_pending_q.push_back(tr);
      end
      `uvm_info(get_full_name(),
                $sformatf("AW collected: ID=%0h Addr=%0h", tr.awid, tr.awaddr), UVM_HIGH)
      aw_ap.write(tr.item_clone());
    end
  end
endtask : collect_aw_channel

task axi_monitor::collect_w_channel();
  axi_mon_write_item w_burst;

  forever begin
    @(m_w_vif.mon_cb);
    if (m_w_vif.mon_cb.wvalid && m_w_vif.mon_cb.wready) begin
      if (w_burst == null) w_burst = axi_mon_write_item::type_id::create("w_burst");

      w_burst.wdata.push_back(m_w_vif.mon_cb.wdata);
      w_burst.wstrb.push_back(m_w_vif.mon_cb.wstrb);
      w_burst.wuser.push_back(m_w_vif.mon_cb.wuser);
      w_burst.wlast.push_back(m_w_vif.mon_cb.wlast);

      if (m_w_vif.mon_cb.wlast) begin
        if (aw_pending_q.size() > 0) begin
          axi_mon_write_item aw_tr = aw_pending_q.pop_front();
          write_q_by_id[aw_tr.awid].push_back(merge_aw(w_burst, aw_tr));
        end else begin
          w_pending_q.push_back(w_burst);
        end

        `uvm_info(get_full_name(), "W burst collected", UVM_HIGH)
        w_ap.write(w_burst.item_clone());
        w_burst = null;
      end
    end
  end
endtask : collect_w_channel

task axi_monitor::collect_b_channel();
  bit [31:0] id;

  forever begin
    @(m_b_vif.mon_cb);
    if (m_b_vif.mon_cb.bvalid && m_b_vif.mon_cb.bready) begin
      id = m_b_vif.mon_cb.bid;
      if (write_q_by_id.exists(id) && write_q_by_id[id].size() > 0) begin
        axi_mon_write_item tr = write_q_by_id[id].pop_front();
        tr.bid      = id;
        tr.bresp    = m_b_vif.mon_cb.bresp;
        tr.buser    = m_b_vif.mon_cb.buser;
        `uvm_info(get_full_name(), $sformatf("FULL write complete: ID=%0h", id), UVM_HIGH)
        tx_ap.write(tr.item_clone());
      end else begin
        `uvm_error("MON_B", $sformatf("B response for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_b_channel

task axi_monitor::collect_ar_channel();
  forever begin
    @(m_ar_vif.mon_cb);
    if (m_ar_vif.mon_cb.arvalid && m_ar_vif.mon_cb.arready) begin
      axi_mon_read_item tr = axi_mon_read_item::type_id::create("ar_tr");

      tr.arid     = m_ar_vif.mon_cb.arid;
      tr.araddr   = m_ar_vif.mon_cb.araddr;
      tr.arlen    = m_ar_vif.mon_cb.arlen;
      tr.arsize   = m_ar_vif.mon_cb.arsize;
      tr.arburst  = m_ar_vif.mon_cb.arburst;
      tr.arlock   = m_ar_vif.mon_cb.arlock;
      tr.arcache  = m_ar_vif.mon_cb.arcache;
      tr.arprot   = m_ar_vif.mon_cb.arprot;
      tr.arqos    = m_ar_vif.mon_cb.arqos;
      tr.arregion = m_ar_vif.mon_cb.arregion;
      tr.aruser   = m_ar_vif.mon_cb.aruser;

      read_q_by_id[tr.arid].push_back(tr);
      `uvm_info(get_full_name(),
                $sformatf("AR collected: ID=%0h Addr=%0h", tr.arid, tr.araddr), UVM_HIGH)
      ar_ap.write(tr.item_clone());
    end
  end
endtask : collect_ar_channel

task axi_monitor::collect_r_channel();
  bit [31:0] id;

  forever begin
    @(m_r_vif.mon_cb);
    if (m_r_vif.mon_cb.rvalid && m_r_vif.mon_cb.rready) begin
      id = m_r_vif.mon_cb.rid;
      if (read_q_by_id.exists(id) && read_q_by_id[id].size() > 0) begin
        axi_mon_read_item tr = read_q_by_id[id][0];
        tr.rid = id;
        tr.rdata.push_back(m_r_vif.mon_cb.rdata);
        tr.rresp.push_back(m_r_vif.mon_cb.rresp);
        tr.rlast.push_back(m_r_vif.mon_cb.rlast);
        tr.ruser.push_back(m_r_vif.mon_cb.ruser);

        if (m_r_vif.mon_cb.rlast) begin
          void'(read_q_by_id[id].pop_front());
          `uvm_info(get_full_name(), $sformatf("FULL read complete: ID=%0h", id), UVM_HIGH)
          tx_ap.write(tr.item_clone());
        end
        r_ap.write(tr.item_clone());
      end else begin
        `uvm_error("MON_R", $sformatf("R data for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_r_channel

function axi_mon_write_item axi_monitor::merge_aw(axi_mon_write_item req,
                                                  axi_mon_write_item aw_item);
  axi_mon_write_item write_item;
  $cast(write_item, req.clone());

  write_item.awid     = aw_item.awid;
  write_item.awaddr   = aw_item.awaddr;
  write_item.awlen    = aw_item.awlen;
  write_item.awsize   = aw_item.awsize;
  write_item.awburst  = aw_item.awburst;
  write_item.awlock   = aw_item.awlock;
  write_item.awcache  = aw_item.awcache;
  write_item.awprot   = aw_item.awprot;
  write_item.awqos    = aw_item.awqos;
  write_item.awregion = aw_item.awregion;
  write_item.awuser   = aw_item.awuser;

  return write_item;
endfunction : merge_aw
