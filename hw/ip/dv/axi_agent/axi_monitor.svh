// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Passive AXI transaction monitor. Snoops the five axi_*_if mon_cb clocking
// blocks and rebuilds whole transactions: AW+W are paired in AW order, B/R are
// matched to their request by ID. Completed transactions go out on tx_ap
// (a write completes at B, a read at RLAST). Interfaces come from axi_agent_cfg.

class axi_monitor extends uvm_monitor;
  `uvm_component_utils(axi_monitor)

  local axi_agent_cfg m_cfg;

  local virtual axi_write_request_if  m_aw_vif;
  local virtual axi_write_data_if     m_w_vif;
  local virtual axi_write_response_if m_b_vif;
  local virtual axi_read_request_if   m_ar_vif;
  local virtual axi_read_data_if      m_r_vif;
  local virtual clk_rst_if            m_clk_rst_vif;   // shared ACLK/ARESETn

  uvm_analysis_port #(axi_mon_item) tx_ap;

  // Write requests/data awaiting their counterpart on the other write channel.
  protected axi_mon_write_item aw_pending_q[$];
  protected axi_mon_write_item w_pending_q[$];

  // Outstanding (merged) requests awaiting their response, keyed by AXI ID.
  protected axi_mon_write_item write_q_by_id [axi_id_t][$];
  protected axi_mon_read_item  read_q_by_id  [axi_id_t][$];

  extern function new(string name, uvm_component parent);
  extern function void set_cfg(axi_agent_cfg cfg);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  // Drop every partially-observed transaction. Called by run_phase once a reset has stopped the
  // collectors.
  extern protected function void cleanup_queues();

  // One collector per channel, run concurrently by run_phase. Together they pair AW with W and
  // match B/R to their request by ID, so the B and R collectors are the ones that complete a
  // transaction and publish it on tx_ap.
  //
  // Each collector reports a sampled X/Z as MON_X. The items are 4-state so an unknown does reach
  // the scoreboard, but it cannot be caught there: `!==` reports two X sides as identical, so an
  // undriven signal seen at both taps would compare equal. Only the fields the scoreboard compares
  // and the IDs it matches on are checked -- the attributes it ignores (lock, cache, prot, qos,
  // region, user) may legitimately be undriven in a given configuration.
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
    wait (m_clk_rst_vif.rst_n);

    fork : isolation_fork
      begin
        fork
          wait (!m_clk_rst_vif.rst_n);

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

      tr.m_awid     = m_aw_vif.mon_cb.awid;
      tr.m_awaddr   = m_aw_vif.mon_cb.awaddr;
      tr.m_awlen    = m_aw_vif.mon_cb.awlen;
      tr.m_awsize   = m_aw_vif.mon_cb.awsize;
      tr.m_awburst  = m_aw_vif.mon_cb.awburst;
      tr.m_awlock   = m_aw_vif.mon_cb.awlock;
      tr.m_awcache  = m_aw_vif.mon_cb.awcache;
      tr.m_awprot   = m_aw_vif.mon_cb.awprot;
      tr.m_awqos    = m_aw_vif.mon_cb.awqos;
      tr.m_awregion = m_aw_vif.mon_cb.awregion;
      tr.m_awuser   = m_aw_vif.mon_cb.awuser;

      if ($isunknown({tr.m_awid, tr.m_awaddr, tr.m_awlen, tr.m_awsize, tr.m_awburst})) begin
        `uvm_error("MON_X",
                   $sformatf("AW sampled with X/Z: id=%0h addr=%0h len=%0h size=%0h burst=%0h",
                             tr.m_awid, tr.m_awaddr, tr.m_awlen, tr.m_awsize, tr.m_awburst))
      end

      if (w_pending_q.size() > 0) begin
        axi_mon_write_item w_tr = w_pending_q.pop_front();
        write_q_by_id[tr.m_awid].push_back(merge_aw(w_tr, tr));
      end else begin
        aw_pending_q.push_back(tr);
      end
      `uvm_info(get_full_name(),
                $sformatf("AW collected: ID=%0h Addr=%0h", tr.m_awid, tr.m_awaddr), UVM_HIGH)
    end
  end
endtask : collect_aw_channel

task axi_monitor::collect_w_channel();
  axi_mon_write_item w_burst;

  forever begin
    @(m_w_vif.mon_cb);
    if (m_w_vif.mon_cb.wvalid && m_w_vif.mon_cb.wready) begin
      if (w_burst == null) w_burst = axi_mon_write_item::type_id::create("w_burst");

      w_burst.m_wdata.push_back(m_w_vif.mon_cb.wdata);
      w_burst.m_wstrb.push_back(m_w_vif.mon_cb.wstrb);
      w_burst.m_wuser.push_back(m_w_vif.mon_cb.wuser);

      if ($isunknown({m_w_vif.mon_cb.wdata, m_w_vif.mon_cb.wstrb, m_w_vif.mon_cb.wlast})) begin
        `uvm_error("MON_X",
                   $sformatf("W beat %0d sampled with X/Z: data=%0h strb=%0h last=%0b",
                             w_burst.m_wdata.size() - 1, m_w_vif.mon_cb.wdata,
                             m_w_vif.mon_cb.wstrb, m_w_vif.mon_cb.wlast))
      end

      if (m_w_vif.mon_cb.wlast) begin
        if (aw_pending_q.size() > 0) begin
          axi_mon_write_item aw_tr = aw_pending_q.pop_front();
          write_q_by_id[aw_tr.m_awid].push_back(merge_aw(w_burst, aw_tr));
        end else begin
          w_pending_q.push_back(w_burst);
        end

        `uvm_info(get_full_name(), "W burst collected", UVM_HIGH)
        w_burst = null;
      end
    end
  end
endtask : collect_w_channel

task axi_monitor::collect_b_channel();
  axi_id_t id;

  forever begin
    @(m_b_vif.mon_cb);
    if (m_b_vif.mon_cb.bvalid && m_b_vif.mon_cb.bready) begin
      id = m_b_vif.mon_cb.bid;
      if ($isunknown({m_b_vif.mon_cb.bid, m_b_vif.mon_cb.bresp})) begin
        `uvm_error("MON_X", $sformatf("B sampled with X/Z: id=%0h resp=%0h",
                                      m_b_vif.mon_cb.bid, m_b_vif.mon_cb.bresp))
      end
      if (write_q_by_id.exists(id) && write_q_by_id[id].size() > 0) begin
        axi_mon_write_item tr = write_q_by_id[id].pop_front();
        tr.m_bid      = id;
        tr.m_bresp    = m_b_vif.mon_cb.bresp;
        tr.m_buser    = m_b_vif.mon_cb.buser;
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

      tr.m_arid     = m_ar_vif.mon_cb.arid;
      tr.m_araddr   = m_ar_vif.mon_cb.araddr;
      tr.m_arlen    = m_ar_vif.mon_cb.arlen;
      tr.m_arsize   = m_ar_vif.mon_cb.arsize;
      tr.m_arburst  = m_ar_vif.mon_cb.arburst;
      tr.m_arlock   = m_ar_vif.mon_cb.arlock;
      tr.m_arcache  = m_ar_vif.mon_cb.arcache;
      tr.m_arprot   = m_ar_vif.mon_cb.arprot;
      tr.m_arqos    = m_ar_vif.mon_cb.arqos;
      tr.m_arregion = m_ar_vif.mon_cb.arregion;
      tr.m_aruser   = m_ar_vif.mon_cb.aruser;

      if ($isunknown({tr.m_arid, tr.m_araddr, tr.m_arlen, tr.m_arsize, tr.m_arburst})) begin
        `uvm_error("MON_X",
                   $sformatf("AR sampled with X/Z: id=%0h addr=%0h len=%0h size=%0h burst=%0h",
                             tr.m_arid, tr.m_araddr, tr.m_arlen, tr.m_arsize, tr.m_arburst))
      end

      read_q_by_id[tr.m_arid].push_back(tr);
      `uvm_info(get_full_name(),
                $sformatf("AR collected: ID=%0h Addr=%0h", tr.m_arid, tr.m_araddr), UVM_HIGH)
    end
  end
endtask : collect_ar_channel

task axi_monitor::collect_r_channel();
  axi_id_t id;

  forever begin
    @(m_r_vif.mon_cb);
    if (m_r_vif.mon_cb.rvalid && m_r_vif.mon_cb.rready) begin
      id = m_r_vif.mon_cb.rid;
      if ($isunknown({m_r_vif.mon_cb.rid, m_r_vif.mon_cb.rdata, m_r_vif.mon_cb.rresp,
                      m_r_vif.mon_cb.rlast})) begin
        `uvm_error("MON_X", $sformatf("R beat sampled with X/Z: id=%0h data=%0h resp=%0h last=%0b",
                                      m_r_vif.mon_cb.rid, m_r_vif.mon_cb.rdata,
                                      m_r_vif.mon_cb.rresp, m_r_vif.mon_cb.rlast))
      end
      if (read_q_by_id.exists(id) && read_q_by_id[id].size() > 0) begin
        axi_mon_read_item tr = read_q_by_id[id][0];
        tr.m_rid = id;
        tr.m_rdata.push_back(m_r_vif.mon_cb.rdata);
        tr.m_rresp.push_back(m_r_vif.mon_cb.rresp);
        tr.m_ruser.push_back(m_r_vif.mon_cb.ruser);

        if (m_r_vif.mon_cb.rlast) begin
          void'(read_q_by_id[id].pop_front());
          `uvm_info(get_full_name(), $sformatf("FULL read complete: ID=%0h", id), UVM_HIGH)
          tx_ap.write(tr.item_clone());
        end
      end else begin
        `uvm_error("MON_R", $sformatf("R data for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_r_channel

function axi_mon_write_item axi_monitor::merge_aw(axi_mon_write_item req,
                                                  axi_mon_write_item aw_item);
  axi_mon_write_item write_item;
  uvm_object         obj;

  obj = req.clone();
  // A $cast from a null handle succeeds, so a failed clone would go unnoticed here.
  `DV_CHECK_FATAL(obj != null, "clone() returned null")
  `DV_CHECK_FATAL($cast(write_item, obj))

  write_item.m_awid     = aw_item.m_awid;
  write_item.m_awaddr   = aw_item.m_awaddr;
  write_item.m_awlen    = aw_item.m_awlen;
  write_item.m_awsize   = aw_item.m_awsize;
  write_item.m_awburst  = aw_item.m_awburst;
  write_item.m_awlock   = aw_item.m_awlock;
  write_item.m_awcache  = aw_item.m_awcache;
  write_item.m_awprot   = aw_item.m_awprot;
  write_item.m_awqos    = aw_item.m_awqos;
  write_item.m_awregion = aw_item.m_awregion;
  write_item.m_awuser   = aw_item.m_awuser;

  return write_item;
endfunction : merge_aw
