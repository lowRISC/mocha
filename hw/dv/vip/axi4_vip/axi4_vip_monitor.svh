// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`ifndef __AXI4_VIP_MONITOR_SVH
`define __AXI4_VIP_MONITOR_SVH

class axi4_vip_monitor extends uvm_monitor;

  `uvm_component_utils(axi4_vip_monitor)

  axi4_vip_cfg     m_cfg;
  virtual axi4_vip_if vif;

  // Analysis Ports
  uvm_analysis_port #(uvm_sequence_item) aw_ap;
  uvm_analysis_port #(uvm_sequence_item) w_ap;
  uvm_analysis_port #(uvm_sequence_item) ar_ap;
  uvm_analysis_port #(uvm_sequence_item) r_ap;
  uvm_analysis_port #(uvm_sequence_item) tx_ap; 

  // --- Internal Storage ---
  axi4_vip_item aw_pending_q[$]; 
  axi4_vip_item w_pending_q[$];  

  // ID-indexed queues to pair Request with Response
  axi4_vip_item write_q_by_id [bit [`AXI4_MAX_ID_WIDTH-1:0]] [$];
  axi4_vip_item read_q_by_id  [bit [`AXI4_MAX_ID_WIDTH-1:0]] [$];

  // Process handles for granular thread control
  local process aw_proc, w_proc, b_proc, ar_proc, r_proc;

  // External Method Declarations
  extern function new(string name, uvm_component parent);
  extern function void build_phase(uvm_phase phase);
  extern task run_phase(uvm_phase phase);
  extern function void stop_processes();
  extern function void cleanup_queues();
  extern task collect_aw_channel();
  extern task collect_w_channel();
  extern task collect_b_channel();
  extern task collect_ar_channel();
  extern task collect_r_channel();
  extern function void merge_tx(axi4_vip_item req, axi4_vip_item data);

endclass : axi4_vip_monitor

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function axi4_vip_monitor::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction : new

function void axi4_vip_monitor::build_phase(uvm_phase phase);
  super.build_phase(phase);
  if (!uvm_config_db #(axi4_vip_cfg)::get(this, "", "m_cfg", m_cfg)) begin
     `uvm_fatal("NOCFG", {"Configuration item must be set for: ", get_full_name(), ".m_cfg"})
  end
  if (!uvm_config_db #(virtual axi4_vip_if)::get(this, get_full_name(), "vif", vif)) begin
    `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(), ".vif"})
  end

  aw_ap = new("aw_ap", this);
  w_ap  = new("w_ap",  this);
  ar_ap = new("ar_ap", this);
  r_ap  = new("r_ap",  this);
  tx_ap = new("tx_ap", this);
endfunction : build_phase

task axi4_vip_monitor::run_phase(uvm_phase phase);
  forever begin
    wait(vif.aresetn === 1'b1);
    
    fork
      begin aw_proc = process::self(); collect_aw_channel(); end
      begin w_proc  = process::self(); collect_w_channel();  end
      begin b_proc  = process::self(); collect_b_channel();  end
      begin ar_proc = process::self(); collect_ar_channel(); end
      begin r_proc  = process::self(); collect_r_channel();  end
    join_none

    wait(vif.aresetn === 1'b0);
    stop_processes();
    cleanup_queues();
  end
endtask : run_phase

function void axi4_vip_monitor::stop_processes();
  process p_list[$] = {aw_proc, w_proc, b_proc, ar_proc, r_proc};
  foreach (p_list[i]) begin
    if (p_list[i] != null) begin
      p_list[i].kill();
    end
  end
endfunction : stop_processes

function void axi4_vip_monitor::cleanup_queues();
  aw_pending_q.delete();
  w_pending_q.delete();
  write_q_by_id.delete();
  read_q_by_id.delete();
endfunction : cleanup_queues

task axi4_vip_monitor::collect_aw_channel();
  bit [`AXI4_MAX_ID_WIDTH-1:0]     id_one     = 1'b1;
  bit [`AXI4_MAX_ADDR_WIDTH-1:0]   addr_one   = 1'b1;
  bit [`AXI4_MAX_USER_WIDTH-1:0]   user_one   = 1'b1;
  bit [`AXI4_MAX_REGION_WIDTH-1:0] region_one = 1'b1;
  bit [`AXI4_MAX_QOS_WIDTH-1:0]    qos_one    = 1'b1;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
      axi4_vip_item tr = axi4_vip_item::type_id::create("aw_tr");
      tr.dir      = AXI_WRITE;
      tr.obs_kind = AXI_AW_CH;
      
      tr.awid     = vif.monitor_cb.awid     & ((id_one     << m_cfg.m_id_width)     - 1);
      tr.awaddr   = vif.monitor_cb.awaddr   & ((addr_one   << m_cfg.m_addr_width)   - 1);
      tr.awuser   = vif.monitor_cb.awuser   & ((user_one   << m_cfg.m_user_width)   - 1);
      tr.awregion = vif.monitor_cb.awregion & ((region_one << m_cfg.m_region_width) - 1);
      tr.awqos    = vif.monitor_cb.awqos    & ((qos_one    << m_cfg.m_qos_width)    - 1);
      
      tr.awlen    = vif.monitor_cb.awlen;
      tr.awsize   = vif.monitor_cb.awsize;
      tr.awburst  = vif.monitor_cb.awburst;
      tr.awlock   = vif.monitor_cb.awlock;
      tr.awcache  = vif.monitor_cb.awcache;
      tr.awprot   = vif.monitor_cb.awprot;

      if (w_pending_q.size() > 0) begin
        axi4_vip_item w_tr = w_pending_q.pop_front();
        merge_tx(tr, w_tr);
        write_q_by_id[tr.awid].push_back(w_tr);
      end else begin
        aw_pending_q.push_back(tr);
      end
      `uvm_info(get_full_name(), $sformatf("AW collected: ID=%0h Addr=%0h", tr.awid, tr.awaddr), UVM_MEDIUM)
      aw_ap.write(tr.clone());
    end
  end
endtask : collect_aw_channel

task axi4_vip_monitor::collect_w_channel();
  bit [`AXI4_MAX_DATA_WIDTH-1:0] data_one = 1'b1;
  bit [`AXI4_MAX_USER_WIDTH-1:0] user_one = 1'b1;
  axi4_vip_item current_burst;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
      if (current_burst == null) begin
        current_burst = axi4_vip_item::type_id::create("w_burst");
      end

      current_burst.dir = AXI_WRITE;
      current_burst.wdata.push_back(vif.monitor_cb.wdata & ((data_one << m_cfg.m_data_width) - 1));
      current_burst.wstrb.push_back(vif.monitor_cb.wstrb & ((data_one << (m_cfg.m_data_width/8)) - 1));
      current_burst.wuser.push_back(vif.monitor_cb.wuser & ((user_one << m_cfg.m_user_width) - 1));
      current_burst.wlast.push_back(vif.monitor_cb.wlast);

      if (vif.monitor_cb.wlast) begin
        if (aw_pending_q.size() > 0) begin
          axi4_vip_item aw_tr = aw_pending_q.pop_front();
          merge_tx(aw_tr, current_burst);
          write_q_by_id[aw_tr.awid].push_back(current_burst);
        end else begin
          w_pending_q.push_back(current_burst);
        end
        current_burst.obs_kind = AXI_W_CH;
        `uvm_info(get_full_name(), "W burst collected", UVM_MEDIUM)
        w_ap.write(current_burst.clone());
        current_burst = null;
      end
    end
  end
endtask : collect_w_channel

task axi4_vip_monitor::collect_b_channel();
  bit [`AXI4_MAX_ID_WIDTH-1:0] id_one = 1'b1;
  bit [`AXI4_MAX_USER_WIDTH-1:0] user_one = 1'b1;
  bit [`AXI4_MAX_ID_WIDTH-1:0] id;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
      id = vif.monitor_cb.bid & ((id_one << m_cfg.m_id_width) - 1);
      if (write_q_by_id.exists(id) && write_q_by_id[id].size() > 0) begin
        axi4_vip_item tr = write_q_by_id[id].pop_front();
        tr.obs_kind = AXI_FULL_WRITE_TR;
        tr.bid      = id;
        tr.bresp    = vif.monitor_cb.bresp;
        tr.buser    = vif.monitor_cb.buser & ((user_one << m_cfg.m_user_width) - 1);
        `uvm_info(get_full_name(), $sformatf("FULL Write complete: ID=%0h", id), UVM_LOW)
        tx_ap.write(tr.clone());
      end else begin
        `uvm_error("MON_B", $sformatf("B-Response for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_b_channel

task axi4_vip_monitor::collect_ar_channel();
  bit [`AXI4_MAX_ID_WIDTH-1:0]     id_one     = 1'b1;
  bit [`AXI4_MAX_ADDR_WIDTH-1:0]   addr_one   = 1'b1;
  bit [`AXI4_MAX_USER_WIDTH-1:0]   user_one   = 1'b1;
  bit [`AXI4_MAX_REGION_WIDTH-1:0] region_one = 1'b1;
  bit [`AXI4_MAX_QOS_WIDTH-1:0]    qos_one    = 1'b1;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
      axi4_vip_item tr = axi4_vip_item::type_id::create("ar_tr");
      tr.dir      = AXI_READ;
      tr.obs_kind = AXI_AR_CH;
      
      tr.arid     = vif.monitor_cb.arid     & ((id_one     << m_cfg.m_id_width)     - 1);
      tr.araddr   = vif.monitor_cb.araddr   & ((addr_one   << m_cfg.m_addr_width)   - 1);
      tr.aruser   = vif.monitor_cb.aruser   & ((user_one   << m_cfg.m_user_width)   - 1);
      tr.arregion = vif.monitor_cb.arregion & ((region_one << m_cfg.m_region_width) - 1);
      tr.arqos    = vif.monitor_cb.arqos    & ((qos_one    << m_cfg.m_qos_width)    - 1);
      
      tr.arlen    = vif.monitor_cb.arlen;
      tr.arsize   = vif.monitor_cb.arsize;
      tr.arburst  = vif.monitor_cb.arburst;
      tr.arlock   = vif.monitor_cb.arlock;
      tr.arcache  = vif.monitor_cb.arcache;
      tr.arprot   = vif.monitor_cb.arprot;
      
      read_q_by_id[tr.arid].push_back(tr);
      `uvm_info(get_full_name(), $sformatf("AR collected: ID=%0h Addr=%0h", tr.arid, tr.araddr), UVM_MEDIUM)
      ar_ap.write(tr.clone());
    end
  end
endtask : collect_ar_channel

task axi4_vip_monitor::collect_r_channel();
  bit [`AXI4_MAX_ID_WIDTH-1:0]   id_one   = 1'b1;
  bit [`AXI4_MAX_DATA_WIDTH-1:0] data_one = 1'b1;
  bit [`AXI4_MAX_USER_WIDTH-1:0] user_one = 1'b1;
  bit [`AXI4_MAX_ID_WIDTH-1:0]   id;

  forever begin
    @(vif.monitor_cb);
    if (vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
      id = vif.monitor_cb.rid & ((id_one << m_cfg.m_id_width) - 1);
      if (read_q_by_id.exists(id) && read_q_by_id[id].size() > 0) begin
        axi4_vip_item tr = read_q_by_id[id][0]; // Peek
        tr.rid = id;
        tr.rdata.push_back(vif.monitor_cb.rdata & ((data_one << m_cfg.m_data_width) - 1));
        tr.rresp.push_back(vif.monitor_cb.rresp);
        tr.ruser.push_back(vif.monitor_cb.ruser & ((user_one << m_cfg.m_user_width) - 1));
        
        if (vif.monitor_cb.rlast) begin
          void'(read_q_by_id[id].pop_front());
          tr.obs_kind = AXI_FULL_READ_TR;
          `uvm_info(get_full_name(), $sformatf("FULL Read complete: ID=%0h", id), UVM_LOW)
          tx_ap.write(tr.clone());
        end else begin
          tr.obs_kind = AXI_R_CH;
        end
        r_ap.write(tr.clone());
      end else begin
        `uvm_error("MON_R", $sformatf("R-Data for unexpected ID: %0h", id))
      end
    end
  end
endtask : collect_r_channel

function void axi4_vip_monitor::merge_tx(axi4_vip_item req, axi4_vip_item data);
  data.dir      = req.dir;
  data.awid     = req.awid;
  data.awaddr   = req.awaddr;
  data.awlen    = req.awlen;
  data.awsize   = req.awsize;
  data.awburst  = req.awburst;
  data.awlock   = req.awlock;
  data.awcache  = req.awcache;
  data.awprot   = req.awprot;
  data.awqos    = req.awqos;
  data.awregion = req.awregion;
  data.awuser   = req.awuser;
endfunction : merge_tx

`endif // __AXI4_VIP_MONITOR_SVH