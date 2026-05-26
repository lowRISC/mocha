// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class axi4_vip_monitor extends uvm_monitor;

  `uvm_component_utils(axi4_vip_monitor)

  typedef bit [      `AXI4_MAX_ID_WIDTH-1:0] axi4_id_t;
  typedef bit [    `AXI4_MAX_ADDR_WIDTH-1:0] axi4_addr_t;
  typedef bit [    `AXI4_MAX_USER_WIDTH-1:0] axi4_user_t;
  typedef bit [  `AXI4_MAX_REGION_WIDTH-1:0] axi4_region_t;
  typedef bit [     `AXI4_MAX_QOS_WIDTH-1:0] axi4_qos_t;
  typedef bit [    `AXI4_MAX_DATA_WIDTH-1:0] axi4_data_t;
  typedef bit [(`AXI4_MAX_DATA_WIDTH/8)-1:0] axi4_strb_t;

  axi4_vip_env_cfg     m_cfg;
  virtual axi4_vip_if vif;

  uvm_analysis_port #(axi4_vip_item) aw_ap;
  uvm_analysis_port #(axi4_vip_item) w_ap;
  uvm_analysis_port #(axi4_vip_item) ar_ap;
  uvm_analysis_port #(axi4_vip_item) r_ap;
  uvm_analysis_port #(axi4_vip_item) tx_ap;

  protected axi4_vip_item aw_pending_q[$];
  protected axi4_vip_item w_pending_q[$];

  protected axi4_vip_item write_q_by_id [axi4_id_t][$];
  protected axi4_vip_item read_q_by_id  [axi4_id_t][$];

  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);

  extern protected function void cleanup_queues();
  extern protected task collect_aw_channel();
  extern protected task collect_w_channel();
  extern protected task collect_b_channel();
  extern protected task collect_ar_channel();
  extern protected task collect_r_channel();

  // Return a version of req with AW information from aw_item.
  extern protected function axi4_vip_item merge_aw(axi4_vip_item req, axi4_vip_item aw_item);

endclass : axi4_vip_monitor

function axi4_vip_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db#(axi4_vip_env_cfg)::get(this, "", "m_cfg", m_cfg)) begin
    `uvm_fatal("NOCFG", {"Configuration item must be set for: ", get_full_name(), ".m_cfg"})
  end
  if (!uvm_config_db#(virtual axi4_vip_if)::get(this, "", "vif", vif)) begin
    `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
  end

  aw_ap = new("aw_ap", this);
  w_ap  = new("w_ap", this);
  ar_ap = new("ar_ap", this);
  r_ap  = new("r_ap", this);
  tx_ap = new("tx_ap", this);
endfunction : build_phase

task axi4_vip_monitor::run_phase(uvm_phase phase);
  forever begin
    wait (vif.aresetn === 1'b1);

    fork : isolation_fork
      begin
        fork
          wait (vif.aresetn === 1'b0);

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

function void axi4_vip_monitor::cleanup_queues();
  aw_pending_q.delete();
  w_pending_q.delete();
  write_q_by_id.delete();
  read_q_by_id.delete();
endfunction : cleanup_queues

task axi4_vip_monitor::collect_aw_channel();
  axi4_id_t     id_mask     = (axi4_id_t'(1)     << m_cfg.m_id_width) - 1;
  axi4_addr_t   addr_mask   = (axi4_addr_t'(1)   << m_cfg.m_addr_width) - 1;
  axi4_user_t   user_mask   = (axi4_user_t'(1)   << m_cfg.m_user_width) - 1;
  axi4_region_t region_mask = (axi4_region_t'(1) << m_cfg.m_region_width) - 1;
  axi4_qos_t    qos_mask    = (axi4_qos_t'(1)    << m_cfg.m_qos_width) - 1;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
      axi4_vip_item tr = axi4_vip_item::type_id::create("aw_tr");
      tr.dir      = AXI_WRITE;
      tr.obs_kind = AXI_AW_CH;

      tr.awid     = vif.monitor_cb.awid & id_mask;
      tr.awaddr   = vif.monitor_cb.awaddr & addr_mask;
      tr.awuser   = vif.monitor_cb.awuser & user_mask;
      tr.awregion = vif.monitor_cb.awregion & region_mask;
      tr.awqos    = vif.monitor_cb.awqos & qos_mask;

      tr.awlen    = vif.monitor_cb.awlen;
      tr.awsize   = vif.monitor_cb.awsize;
      tr.awburst  = vif.monitor_cb.awburst;
      tr.awlock   = vif.monitor_cb.awlock;
      tr.awcache  = vif.monitor_cb.awcache;
      tr.awprot   = vif.monitor_cb.awprot;

      if (w_pending_q.size() > 0) begin
        axi4_vip_item w_tr = w_pending_q.pop_front();
        write_q_by_id[tr.awid].push_back(merge_aw(w_tr, tr));
      end else begin
        aw_pending_q.push_back(tr);
      end
      `uvm_info(get_full_name(),
                $sformatf("AW collected: ID=%0h Addr=%0h", tr.awid, tr.awaddr),
                UVM_HIGH)
      aw_ap.write(tr.item_clone());
    end
  end
endtask : collect_aw_channel

task axi4_vip_monitor::collect_w_channel();
  axi4_data_t   data_mask = (axi4_data_t'(1) << m_cfg.m_data_width) - 1;
  axi4_strb_t   strb_mask = (axi4_strb_t'(1) << (m_cfg.m_data_width / 8)) - 1;
  axi4_user_t   user_mask = (axi4_user_t'(1) << m_cfg.m_user_width) - 1;
  axi4_vip_item w_burst;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
      if (w_burst == null) begin
        w_burst = axi4_vip_item::type_id::create("w_burst");
      end

      w_burst.dir = AXI_WRITE;
      w_burst.wdata.push_back(vif.monitor_cb.wdata & data_mask);
      w_burst.wstrb.push_back(vif.monitor_cb.wstrb & strb_mask);
      w_burst.wuser.push_back(vif.monitor_cb.wuser & user_mask);
      w_burst.wlast.push_back(vif.monitor_cb.wlast);

      if (vif.monitor_cb.wlast) begin
        w_burst.obs_kind = AXI_W_CH;

        if (aw_pending_q.size() > 0) begin
          axi4_vip_item aw_tr = aw_pending_q.pop_front();
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

task axi4_vip_monitor::collect_b_channel();
  axi4_id_t   id_mask = (axi4_id_t'(1)   << m_cfg.m_id_width) - 1;
  axi4_user_t user_mask = (axi4_user_t'(1) << m_cfg.m_user_width) - 1;
  axi4_id_t   id;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
      id = vif.monitor_cb.bid & id_mask;
      if (write_q_by_id.exists(id) && write_q_by_id[id].size() > 0) begin
        axi4_vip_item tr = write_q_by_id[id].pop_front();
        tr.obs_kind = AXI_FULL_WRITE_TR;
        tr.bid      = id;
        tr.bresp    = vif.monitor_cb.bresp;
        tr.buser    = vif.monitor_cb.buser & user_mask;
        `uvm_info(get_full_name(), $sformatf("FULL Write complete: ID=%0h", id), UVM_LOW)
        tx_ap.write(tr.item_clone());
      end else begin
        `uvm_error("MON_B", $sformatf("B-Response for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_b_channel

task axi4_vip_monitor::collect_ar_channel();
  axi4_id_t     id_mask     = (axi4_id_t'(1)     << m_cfg.m_id_width) - 1;
  axi4_addr_t   addr_mask   = (axi4_addr_t'(1)   << m_cfg.m_addr_width) - 1;
  axi4_user_t   user_mask   = (axi4_user_t'(1)   << m_cfg.m_user_width) - 1;
  axi4_region_t region_mask = (axi4_region_t'(1) << m_cfg.m_region_width) - 1;
  axi4_qos_t    qos_mask    = (axi4_qos_t'(1)    << m_cfg.m_qos_width) - 1;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
      axi4_vip_item tr = axi4_vip_item::type_id::create("ar_tr");
      tr.dir      = AXI_READ;
      tr.obs_kind = AXI_AR_CH;

      tr.arid     = vif.monitor_cb.arid & id_mask;
      tr.araddr   = vif.monitor_cb.araddr & addr_mask;
      tr.aruser   = vif.monitor_cb.aruser & user_mask;
      tr.arregion = vif.monitor_cb.arregion & region_mask;
      tr.arqos    = vif.monitor_cb.arqos & qos_mask;

      tr.arlen    = vif.monitor_cb.arlen;
      tr.arsize   = vif.monitor_cb.arsize;
      tr.arburst  = vif.monitor_cb.arburst;
      tr.arlock   = vif.monitor_cb.arlock;
      tr.arcache  = vif.monitor_cb.arcache;
      tr.arprot   = vif.monitor_cb.arprot;

      read_q_by_id[tr.arid].push_back(tr);
      `uvm_info(get_full_name(),
                $sformatf("AR collected: ID=%0h Addr=%0h", tr.arid, tr.araddr),
                UVM_HIGH)
      ar_ap.write(tr.item_clone());
    end
  end
endtask : collect_ar_channel

task axi4_vip_monitor::collect_r_channel();
  axi4_id_t   id_mask   = (axi4_id_t'(1)   << m_cfg.m_id_width) - 1;
  axi4_data_t data_mask = (axi4_data_t'(1) << m_cfg.m_data_width) - 1;
  axi4_user_t user_mask = (axi4_user_t'(1) << m_cfg.m_user_width) - 1;
  axi4_id_t   id;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
      id = vif.monitor_cb.rid & id_mask;
      if (read_q_by_id.exists(id) && read_q_by_id[id].size() > 0) begin
        axi4_vip_item tr = read_q_by_id[id][0];
        tr.rid = id;
        tr.rdata.push_back(vif.monitor_cb.rdata & data_mask);
        tr.rresp.push_back(vif.monitor_cb.rresp);
        tr.rlast.push_back(vif.monitor_cb.rlast);
        tr.ruser.push_back(vif.monitor_cb.ruser & user_mask);

        if (vif.monitor_cb.rlast) begin
          void'(read_q_by_id[id].pop_front());
          tr.obs_kind = AXI_FULL_READ_TR;
          `uvm_info(get_full_name(), $sformatf("FULL Read complete: ID=%0h", id), UVM_LOW)
          tx_ap.write(tr.item_clone());
        end else begin
          tr.obs_kind = AXI_R_CH;
        end
        r_ap.write(tr.item_clone());
      end else begin
        `uvm_error("MON_R", $sformatf("R-Data for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_r_channel

function axi4_vip_item axi4_vip_monitor::merge_aw(axi4_vip_item req, axi4_vip_item aw_item);
  axi4_vip_item write_item = req.item_clone();

  if (aw_item.dir != AXI_WRITE) begin
    `uvm_fatal("MON_AW", "Cannot take AW information from non-write aw_item.")
  end

  write_item.dir      = AXI_WRITE;
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
