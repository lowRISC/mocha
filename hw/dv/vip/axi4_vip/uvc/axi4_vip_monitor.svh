`ifndef __AXI4_VIP_MONITOR_SVH
`define __AXI4_VIP_MONITOR_SVH

class axi4_vip_monitor extends uvm_monitor;

  `uvm_component_utils(axi4_vip_monitor)

  axi4_vip_agent_config m_cfg;
  virtual axi4_vip_if   vif;

  // Analysis Ports
  uvm_analysis_port #(axi4_vip_transaction) aw_ap;
  uvm_analysis_port #(axi4_vip_transaction) w_ap;
  uvm_analysis_port #(axi4_vip_transaction) b_ap;
  uvm_analysis_port #(axi4_vip_transaction) ar_ap;
  uvm_analysis_port #(axi4_vip_transaction) r_ap;
  uvm_analysis_port #(axi4_vip_transaction) tx_ap; 

  // --- Internal Storage ---
  axi4_vip_transaction aw_pending_q[$]; 
  axi4_vip_transaction w_pending_q[$];  

  // ID-indexed queues to pair Request with Response
  axi4_vip_transaction write_q_by_id [bit [`AXI4_MAX_ID_WIDTH-1:0]] [$];
  axi4_vip_transaction read_q_by_id  [bit [`AXI4_MAX_ID_WIDTH-1:0]] [$];

  // Process handles for granular thread control
  local process aw_proc, w_proc, b_proc, ar_proc, r_proc;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axi4_vip_agent_config)::get(this, "", "m_cfg", m_cfg))
       `uvm_fatal("NOCFG", "m_cfg not found")
    if (!uvm_config_db #(virtual axi4_vip_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "vif not found")

    aw_ap = new("aw_ap", this);
    w_ap  = new("w_ap",  this);
    b_ap  = new("b_ap",  this);
    ar_ap = new("ar_ap", this);
    r_ap  = new("r_ap",  this);
    tx_ap = new("tx_ap", this);
  endfunction

  // ---------------------------------------------------------------------------
  // Run Phase
  // ---------------------------------------------------------------------------
  task run_phase(uvm_phase phase);
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
  endtask

  function void stop_processes();
    process p_list[$] = {aw_proc, w_proc, b_proc, ar_proc, r_proc};
    foreach (p_list[i]) if (p_list[i] != null) p_list[i].kill();
  endfunction

  function void cleanup_queues();
    aw_pending_q.delete();
    w_pending_q.delete();
    write_q_by_id.delete();
    read_q_by_id.delete();
  endfunction

  // ---------------------------------------------------------------------------
  // Write Address Channel
  // ---------------------------------------------------------------------------
  task collect_aw_channel();
    forever begin
      @(vif.monitor_cb);
      if(vif.monitor_cb.awvalid && vif.monitor_cb.awready) begin
        axi4_vip_transaction tr = axi4_vip_transaction::type_id::create("aw_tr");
        tr.dir      = AXI_WRITE;
        
        // Apply Masking based on Config
        tr.awid     = vif.monitor_cb.awid     & ((64'h1 << m_cfg.m_id_width) - 1);
        tr.awaddr   = vif.monitor_cb.awaddr   & ((64'h1 << m_cfg.m_addr_width) - 1);
        tr.awuser   = vif.monitor_cb.awuser   & ((64'h1 << m_cfg.m_user_width) - 1);
        tr.awregion = vif.monitor_cb.awregion & ((64'h1 << m_cfg.m_region_width) - 1);
        tr.awqos    = vif.monitor_cb.awqos    & ((64'h1 << m_cfg.m_qos_width) - 1);
        
        tr.awlen    = vif.monitor_cb.awlen;
        tr.awsize   = vif.monitor_cb.awsize;
        tr.awburst  = vif.monitor_cb.awburst;
        tr.awlock   = vif.monitor_cb.awlock;
        tr.awcache  = vif.monitor_cb.awcache;
        tr.awprot   = vif.monitor_cb.awprot;

        if (w_pending_q.size() > 0) begin
          axi4_vip_transaction w_tr = w_pending_q.pop_front();
          merge_tx(tr, w_tr);
          write_q_by_id[tr.awid].push_back(w_tr);
        end else begin
          aw_pending_q.push_back(tr);
        end
        aw_ap.write(tr.clone());
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Write Data Channel
  // ---------------------------------------------------------------------------
  task collect_w_channel();
    axi4_vip_transaction current_burst;
    forever begin
      @(vif.monitor_cb);
      if(vif.monitor_cb.wvalid && vif.monitor_cb.wready) begin
        if (current_burst == null) current_burst = axi4_vip_transaction::type_id::create("w_burst");

        current_burst.wdata.push_back(vif.monitor_cb.wdata & ((64'h1 << m_cfg.m_data_width) - 1));
        current_burst.wstrb.push_back(vif.monitor_cb.wstrb & ((64'h1 << (m_cfg.m_data_width/8)) - 1));
        current_burst.wuser.push_back(vif.monitor_cb.wuser & ((64'h1 << m_cfg.m_user_width) - 1));
        current_burst.wlast.push_back(vif.monitor_cb.wlast);

        if (vif.monitor_cb.wlast) begin
          if (aw_pending_q.size() > 0) begin
            axi4_vip_transaction aw_tr = aw_pending_q.pop_front();
            merge_tx(aw_tr, current_burst);
            write_q_by_id[aw_tr.awid].push_back(current_burst);
          end else begin
            w_pending_q.push_back(current_burst);
          end
          w_ap.write(current_burst.clone());
          current_burst = null;
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Write Response Channel
  // ---------------------------------------------------------------------------
  task collect_b_channel();
    bit [`AXI4_MAX_ID_WIDTH-1:0] id;
    forever begin
      @(vif.monitor_cb);
      if(vif.monitor_cb.bvalid && vif.monitor_cb.bready) begin
        id = vif.monitor_cb.bid & ((64'h1 << m_cfg.m_id_width) - 1);
        if(write_q_by_id.exists(id) && write_q_by_id[id].size() > 0) begin
          axi4_vip_transaction tr = write_q_by_id[id].pop_front();
          tr.bid   = id;
          tr.bresp = vif.monitor_cb.bresp;
          tr.buser = vif.monitor_cb.buser & ((64'h1 << m_cfg.m_user_width) - 1);
          b_ap.write(tr.clone());
          tx_ap.write(tr.clone());
        end else begin
          `uvm_error("MON_B", $sformatf("B-Response for unexpected ID: %0h", id))
        end
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Read Address Channel
  // ---------------------------------------------------------------------------
  task collect_ar_channel();
    forever begin
      @(vif.monitor_cb);
      if(vif.monitor_cb.arvalid && vif.monitor_cb.arready) begin
        axi4_vip_transaction tr = axi4_vip_transaction::type_id::create("ar_tr");
        tr.dir      = AXI_READ;
        
        tr.arid     = vif.monitor_cb.arid     & ((64'h1 << m_cfg.m_id_width) - 1);
        tr.araddr   = vif.monitor_cb.araddr   & ((64'h1 << m_cfg.m_addr_width) - 1);
        tr.aruser   = vif.monitor_cb.aruser   & ((64'h1 << m_cfg.m_user_width) - 1);
        tr.arregion = vif.monitor_cb.arregion & ((64'h1 << m_cfg.m_region_width) - 1);
        tr.arqos    = vif.monitor_cb.arqos    & ((64'h1 << m_cfg.m_qos_width) - 1);
        
        tr.arlen    = vif.monitor_cb.arlen;
        tr.arsize   = vif.monitor_cb.arsize;
        tr.arburst  = vif.monitor_cb.arburst;
        tr.arlock   = vif.monitor_cb.arlock;
        tr.arcache  = vif.monitor_cb.arcache;
        tr.arprot   = vif.monitor_cb.arprot;
        
        read_q_by_id[tr.arid].push_back(tr);
        ar_ap.write(tr.clone());
      end
    end
  endtask

  // ---------------------------------------------------------------------------
  // Read Data Channel
  // ---------------------------------------------------------------------------
  task collect_r_channel();
    bit [`AXI4_MAX_ID_WIDTH-1:0] id;
    forever begin
      @(vif.monitor_cb);
      if(vif.monitor_cb.rvalid && vif.monitor_cb.rready) begin
        id = vif.monitor_cb.rid & ((64'h1 << m_cfg.m_id_width) - 1);
        if(read_q_by_id.exists(id) && read_q_by_id[id].size() > 0) begin
          axi4_vip_transaction tr = read_q_by_id[id][0]; // Peek
          tr.rid = id;
          tr.rdata.push_back(vif.monitor_cb.rdata & ((64'h1 << m_cfg.m_data_width) - 1));
          tr.rresp.push_back(vif.monitor_cb.rresp);
          tr.ruser.push_back(vif.monitor_cb.ruser & ((64'h1 << m_cfg.m_user_width) - 1));
          
          if(vif.monitor_cb.rlast) begin
            void'(read_q_by_id[id].pop_front());
            tx_ap.write(tr.clone());
          end
          r_ap.write(tr.clone());
        end else begin
          `uvm_error("MON_R", $sformatf("R-Data for unexpected ID: %0h", id))
        end
      end
    end
  endtask

  function void merge_tx(axi4_vip_transaction req, axi4_vip_transaction data);
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
  endfunction

endclass
`endif