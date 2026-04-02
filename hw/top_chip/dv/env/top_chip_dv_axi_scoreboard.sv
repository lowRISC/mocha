// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(top_chip_dv_axi_scoreboard)

  axi_addr_range_t mem_map[$];
  string             default_subordinate_id = "INTERNAL_XBAR_DEFAULT";

  // Analysis Implementation Ports
  `uvm_analysis_imp_decl(_mgr0_cva6)
  `uvm_analysis_imp_decl(_sub0_sram)
  `uvm_analysis_imp_decl(_sub1_mailbox)
  `uvm_analysis_imp_decl(_sub2_tlcrossbar)
  `uvm_analysis_imp_decl(_sub3_dram)

  uvm_analysis_imp_mgr0_cva6       #(uvm_sequence_item, top_chip_dv_axi_scoreboard) mgr0_cva6_imp;
  uvm_analysis_imp_sub0_sram       #(uvm_sequence_item, top_chip_dv_axi_scoreboard) sub0_sram_imp;
  uvm_analysis_imp_sub1_mailbox    #(uvm_sequence_item, top_chip_dv_axi_scoreboard) sub1_mailbox_imp;
  uvm_analysis_imp_sub2_tlcrossbar #(uvm_sequence_item, top_chip_dv_axi_scoreboard) sub2_tlcrossbar_imp;
  uvm_analysis_imp_sub3_dram       #(uvm_sequence_item, top_chip_dv_axi_scoreboard) sub3_dram_imp;

  // Queues to handle out-of-order monitor arrivals
  // [SubordinateName][MaskedID]
  axi4_vip_item expect_q[string][bit[top_pkg::AxiIdWidth-1:0]][$]; // Manager arrived first
  axi4_vip_item actual_q[string][bit[top_pkg::AxiIdWidth-1:0]][$]; // Subordinate arrived first

  // External Method Declarations
  extern function new(string name, uvm_component parent);
  extern virtual function void build_phase(uvm_phase phase);
  extern function bit [63:0] get_orig_id(bit [top_pkg::AxiIdWidth-1:0] full_id);
  extern function string decode_addr(bit [63:0] addr);
  extern virtual function void perform_comparison(axi4_vip_item exp, axi4_vip_item act, string slv);
  extern virtual function void write_mgr0_cva6(uvm_sequence_item item);
  extern virtual function void check_subordinate_arrival(uvm_sequence_item item, string slv_id);
  extern virtual function void write_sub0_sram(uvm_sequence_item tr);
  extern virtual function void write_sub1_mailbox(uvm_sequence_item tr);
  extern virtual function void write_sub2_tlcrossbar(uvm_sequence_item tr);
  extern virtual function void write_sub3_dram(uvm_sequence_item tr);
  extern virtual function void check_phase(uvm_phase phase);

endclass : top_chip_dv_axi_scoreboard

//------------------------------------------------------------------------------
// External Method Implementations
//------------------------------------------------------------------------------

function top_chip_dv_axi_scoreboard::new(string name, uvm_component parent);
  super.new(name, parent);
  mgr0_cva6_imp       = new("mgr0_cva6_imp",       this);
  sub0_sram_imp       = new("sub0_sram_imp",       this);
  sub1_mailbox_imp    = new("sub1_mailbox_imp",    this);
  sub2_tlcrossbar_imp = new("sub2_tlcrossbar_imp", this);
  sub3_dram_imp       = new("sub3_dram_imp",       this);
endfunction : new

function void top_chip_dv_axi_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);

  // Specific Address Mapping
  mem_map.push_back('{"sub0_sram",       (top_pkg::SRAMBase),       (top_pkg::SRAMBase       + top_pkg::SRAMLength     - 1)});
  mem_map.push_back('{"sub1_mailbox",    (top_pkg::MailboxBase),    (top_pkg::MailboxBase    + top_pkg::MailboxLength  - 1)});
  mem_map.push_back('{"sub2_tlcrossbar", (top_pkg::TlCrossbarBase), (top_pkg::TlCrossbarBase + top_pkg::TlCrossbarBase - 1)});
  mem_map.push_back('{"sub3_dram",       (top_pkg::DRAMBase),       (top_pkg::DRAMBase       + top_pkg::DRAMBase       - 1)});
endfunction : build_phase

function bit [top_pkg::AxiIdWidth-1:0] top_chip_dv_axi_scoreboard::get_orig_id(bit [63:0] full_id);
  return full_id & ((1 << top_pkg::AxiIdWidth) - 1);
endfunction : get_orig_id

function string top_chip_dv_axi_scoreboard::decode_addr(bit [63:0] addr);
  foreach (mem_map[i]) begin
    if (addr >= mem_map[i].start_addr && addr <= mem_map[i].end_addr)
      return mem_map[i].subordinate_name;
  end
  return default_subordinate_id;
endfunction : decode_addr

function void top_chip_dv_axi_scoreboard::perform_comparison(axi4_vip_item exp, axi4_vip_item act, string slv);
  bit [top_pkg::AxiIdWidth-1:0] mid = get_orig_id((act.dir == AXI_WRITE) ? act.bid : act.rid);
  
  if (act.dir == AXI_WRITE) begin
    if (act.awaddr  !== exp.awaddr  || act.awlen   !== exp.awlen  || 
        act.awsize  !== exp.awsize  || act.awburst !== exp.awburst) begin
      `uvm_error("SCB_ATTR_WR", $sformatf("Write Attribute mismatch on %s ID:%h", slv, mid))
    end

    if (act.wdata != exp.wdata) begin
      `uvm_error("SCB_WDATA", $sformatf("Write Data mismatch on %s ID:%h", slv, mid))
    end

    if (act.wstrb != exp.wstrb) begin
      `uvm_error("SCB_WSTRB", $sformatf("Write Strobe mismatch on %s ID:%h", slv, mid))
    end
  end else begin
    if (act.araddr  !== exp.araddr  || act.arlen   !== exp.arlen  || 
        act.arsize  !== exp.arsize  || act.arburst !== exp.arburst) begin
      `uvm_error("SCB_ATTR_RD", $sformatf("Read Attribute mismatch on %s ID:%h", slv, mid))
    end

    if (act.rdata != exp.rdata) begin
      `uvm_error("SCB_RDATA", $sformatf("Read Data mismatch on %s ID:%h", slv, mid))
    end

    if (act.rresp != exp.rresp) begin
      `uvm_error("SCB_RRESP", $sformatf("Read Response mismatch on %s ID:%h", slv, mid))
    end
  end
endfunction : perform_comparison

function void top_chip_dv_axi_scoreboard::write_mgr0_cva6(uvm_sequence_item item);
  axi4_vip_item tr;
  if (!$cast(tr, item)) begin
    `uvm_fatal("TYPE", "Cast failed")
  end

  begin
    bit [63:0] addr = (tr.dir == AXI_WRITE) ? tr.awaddr : tr.araddr;
    bit [63:0] id   = (tr.dir == AXI_WRITE) ? tr.awid   : tr.arid;
    string target_slv = decode_addr(addr);
    bit [63:0] mid    = get_orig_id(id);

    if (target_slv == default_subordinate_id) begin
       // Decoder error check would go here
    end else begin
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
endfunction : write_mgr0

function void top_chip_dv_axi_scoreboard::check_subordinate_arrival(uvm_sequence_item item, string slv_id);
  axi4_vip_item act;
  if (!$cast(act, item)) `uvm_fatal("TYPE", "Cast failed")

  begin
    bit [63:0] mid = get_orig_id((act.dir == AXI_WRITE) ? act.bid : act.rid);
    
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
endfunction : check_subordinate_arrival

function void top_chip_dv_axi_scoreboard::write_sub0_sram(uvm_sequence_item tr); 
  check_subordinate_arrival(tr, "sub0_sram"); 
endfunction : write_sub0

function void top_chip_dv_axi_scoreboard::write_sub1_mailbox(uvm_sequence_item tr); 
  check_subordinate_arrival(tr, "sub1_mailbox"); 
endfunction : write_sub1

function void top_chip_dv_axi_scoreboard::write_sub2_tlcrossbar(uvm_sequence_item tr); 
  check_subordinate_arrival(tr, "sub2_tlcrossbar"); 
endfunction : write_sub2

function void top_chip_dv_axi_scoreboard::write_sub3_dram(uvm_sequence_item tr); 
  check_subordinate_arrival(tr, "sub3_dram"); 
endfunction : write_sub3

function void top_chip_dv_axi_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);

  // Check for requests that entered the fabric but never exited
  foreach (expect_q[s, i]) begin
    if (expect_q[s][i].size() > 0) begin
      `uvm_error("SCB_DRAIN_DROP", $sformatf("DROPPED: Master req for %s (ID %h) lost in fabric", s, i))
    end
  end
  
  // Check for responses that exited the fabric but weren't requested/seen by Master
  foreach (actual_q[s, i]) begin
    if (actual_q[s][i].size() > 0) begin
      `uvm_error("SCB_DRAIN_GHOST", $sformatf("GHOST: Slave %s (ID %h) responded but Master missed it", s, i))
    end
  end
endfunction : check_phase