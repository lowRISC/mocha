// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(top_chip_dv_axi_scoreboard)

  // Local Address Map Struct
  typedef struct {
    string     slave_name;
    bit [63:0] start_addr;
    bit [63:0] end_addr;
  } local_addr_range_t;

  local_addr_range_t mem_map[$];
  string             default_slave_id = "INTERNAL_XBAR_DEFAULT";
  int unsigned       master_id_width  = 4; 

  // Analysis Implementation Ports
  `uvm_analysis_imp_decl(_mst0)
  `uvm_analysis_imp_decl(_slv0)
  `uvm_analysis_imp_decl(_slv1)

  uvm_analysis_imp_mst0 #(uvm_sequence_item, top_chip_dv_axi_scoreboard) mst0_imp;
  uvm_analysis_imp_slv0 #(uvm_sequence_item, top_chip_dv_axi_scoreboard) slv0_imp;
  uvm_analysis_imp_slv1 #(uvm_sequence_item, top_chip_dv_axi_scoreboard) slv1_imp;

  // Queues to handle out-of-order monitor arrivals
  // [SlaveName][MaskedID]
  axi4_vip_item expect_q[string][bit[63:0]][$]; // Master arrived first
  axi4_vip_item actual_q[string][bit[63:0]][$]; // Slave arrived first

  function new(string name, uvm_component parent);
    super.new(name, parent);
    mst0_imp = new("mst0_imp", this);
    slv0_imp = new("slv0_imp", this);
    slv1_imp = new("slv1_imp", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Specific Address Mapping
    mem_map.push_back('{"slv0", 64'h1000_0000, 64'h1001_FFFF});
    mem_map.push_back('{"slv1", 64'h4000_0000, 64'h4FFF_FFFF});
  endfunction

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  function bit [63:0] get_orig_id(bit [63:0] full_id);
    return full_id & ((1 << master_id_width) - 1);
  endfunction

  function string decode_addr(bit [63:0] addr);
    foreach (mem_map[i]) begin
      if (addr >= mem_map[i].start_addr && addr <= mem_map[i].end_addr)
        return mem_map[i].slave_name;
    end
    return default_slave_id;
  endfunction

  // ------------------------------------------------------------------
  // Unified Comparison Logic
  // ------------------------------------------------------------------
  virtual function void perform_comparison(axi4_vip_item exp, axi4_vip_item act, string slv);
    bit [63:0] mid = get_orig_id((act.dir == AXI_WRITE) ? act.bid : act.rid);
    
    if (act.dir == AXI_WRITE) begin
      if (act.awaddr  !== exp.awaddr  || act.awlen   !== exp.awlen  || 
          act.awsize  !== exp.awsize  || act.awburst !== exp.awburst) begin
        `uvm_error("SCB_ATTR_WR", $sformatf("Write Attribute mismatch on %s ID:%h", slv, mid))
      end
      if (act.wdata != exp.wdata) `uvm_error("SCB_WDATA", $sformatf("Write Data mismatch on %s ID:%h", slv, mid))
      if (act.wstrb != exp.wstrb) `uvm_error("SCB_WSTRB", $sformatf("Write Strobe mismatch on %s ID:%h", slv, mid))
    end else begin
      if (act.araddr  !== exp.araddr  || act.arlen   !== exp.arlen  || 
          act.arsize  !== exp.arsize  || act.arburst !== exp.arburst) begin
        `uvm_error("SCB_ATTR_RD", $sformatf("Read Attribute mismatch on %s ID:%h", slv, mid))
      end
      if (act.rdata != exp.rdata) `uvm_error("SCB_RDATA", $sformatf("Read Data mismatch on %s ID:%h", slv, mid))
      if (act.rresp != exp.rresp) `uvm_error("SCB_RRESP", $sformatf("Read Response mismatch on %s ID:%h", slv, mid))
    end
  endfunction

  // ------------------------------------------------------------------
  // Master Port Callback (mst0)
  // ------------------------------------------------------------------
  virtual function void write_mst0(uvm_sequence_item item);
    axi4_vip_item tr;
    if (!$cast(tr, item)) `uvm_fatal("TYPE", "Cast failed")

    begin
      bit [63:0] addr = (tr.dir == AXI_WRITE) ? tr.awaddr : tr.araddr;
      bit [63:0] id   = (tr.dir == AXI_WRITE) ? tr.awid   : tr.arid;
      bit [1:0]  resp = (tr.dir == AXI_WRITE) ? tr.bresp[0] : tr.rresp[0];
      string target_slv = decode_addr(addr);
      bit [63:0] mid    = get_orig_id(id);

      if (target_slv == default_slave_id) begin
        if (resp != 2'b11) `uvm_error("SCB_DECERR", $sformatf("No DECERR for addr %h", addr))
      end else begin
        // Check if Slave monitor already sent the data
        if (actual_q[target_slv].exists(mid) && actual_q[target_slv][mid].size() > 0) begin
          axi4_vip_item act_tr = actual_q[target_slv][mid].pop_front();
          perform_comparison(tr, act_tr, target_slv);
          if (actual_q[target_slv][mid].size() == 0) actual_q[target_slv].delete(mid);
        end else begin
          axi4_vip_item exp_tr;
          $cast(exp_tr, tr.clone());
          expect_q[target_slv][mid].push_back(exp_tr);
        end
      end
    end
  endfunction

  // ------------------------------------------------------------------
  // Slave Port Arrival Logic
  // ------------------------------------------------------------------
  virtual function void check_slave_arrival(uvm_sequence_item item, string slv_id);
    axi4_vip_item act;
    if (!$cast(act, item)) `uvm_fatal("TYPE", "Cast failed")

    begin
      bit [63:0] mid = get_orig_id((act.dir == AXI_WRITE) ? act.bid : act.rid);
      
      // Check if Master monitor already sent the request
      if (expect_q[slv_id].exists(mid) && expect_q[slv_id][mid].size() > 0) begin
        axi4_vip_item exp_tr = expect_q[slv_id][mid].pop_front();
        perform_comparison(exp_tr, act, slv_id);
        if (expect_q[slv_id][mid].size() == 0) expect_q[slv_id].delete(mid);
      end else begin
        axi4_vip_item act_tr;
        $cast(act_tr, act.clone());
        actual_q[slv_id][mid].push_back(act_tr);
      end
    end
  endfunction

  virtual function void write_slv0(uvm_sequence_item tr); check_slave_arrival(tr, "slv0"); endfunction
  virtual function void write_slv1(uvm_sequence_item tr); check_slave_arrival(tr, "slv1"); endfunction

  // ------------------------------------------------------------------
  // Final Checks
  // ------------------------------------------------------------------
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    foreach (expect_q[s]) foreach (expect_q[s][i]) if (expect_q[s][i].size() > 0)
      `uvm_error("SCB_DRAIN", $sformatf("Master req for %s (ID %h) never reached Slave", s, i))
    
    foreach (actual_q[s]) foreach (actual_q[s][i]) if (actual_q[s][i].size() > 0)
      `uvm_error("SCB_DRAIN", $sformatf("Slave trans on %s (ID %h) never reached Master", s, i))
  endfunction

endclass