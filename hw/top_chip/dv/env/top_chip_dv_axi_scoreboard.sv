// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_axi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(top_chip_dv_axi_scoreboard)

  typedef bit [top_pkg::AxiIdWidth-1:0] masked_id_t;

  axi_addr_range_t mem_map[$];
  string           default_subordinate_id = "INTERNAL_XBAR_DEFAULT";

  `uvm_analysis_imp_decl(_mgr0_cva6)
  `uvm_analysis_imp_decl(_sub0_romctrlmem)
  `uvm_analysis_imp_decl(_sub1_sram)
  `uvm_analysis_imp_decl(_sub2_mailbox)
  `uvm_analysis_imp_decl(_sub3_tlcrossbar)
  `uvm_analysis_imp_decl(_sub4_dram)

  uvm_analysis_imp_mgr0_cva6       #(axi4_vip_item, top_chip_dv_axi_scoreboard) mgr0_cva6_imp;
  uvm_analysis_imp_sub0_romctrlmem #(axi4_vip_item, top_chip_dv_axi_scoreboard) sub0_romctrlmem_imp;
  uvm_analysis_imp_sub1_sram       #(axi4_vip_item, top_chip_dv_axi_scoreboard) sub1_sram_imp;
  uvm_analysis_imp_sub2_mailbox    #(axi4_vip_item, top_chip_dv_axi_scoreboard) sub2_mailbox_imp;
  uvm_analysis_imp_sub3_tlcrossbar #(axi4_vip_item, top_chip_dv_axi_scoreboard) sub3_tlcrossbar_imp;
  uvm_analysis_imp_sub4_dram       #(axi4_vip_item, top_chip_dv_axi_scoreboard) sub4_dram_imp;

  protected axi4_vip_item expected_queue[string][masked_id_t][$];
  protected axi4_vip_item actual_queue[string][masked_id_t][$];

  extern function new(string name, uvm_component parent);
  extern virtual function void build_phase(uvm_phase phase);
  // Record a subordinate address range from its base and size.
  extern protected function void add_mem_range(string name,
                                               bit [63:0] start_addr,
                                               bit [63:0] addr_size);
  // Mask the AXI ID back to the manager ID width before matching transactions.
  extern protected function masked_id_t get_masked_id(bit [63:0] raw_id);
  // Return the subordinate range name that contains addr, or the default target.
  extern protected function string addr_to_mem_range(bit [63:0] addr);
  extern virtual function void perform_comparison(axi4_vip_item exp,
                                                  axi4_vip_item act,
                                                  string sub);

  extern virtual function void write_mgr0_cva6(axi4_vip_item tr);
  extern virtual function void write_sub0_romctrlmem(axi4_vip_item tr);
  extern virtual function void write_sub1_sram(axi4_vip_item tr);
  extern virtual function void write_sub2_mailbox(axi4_vip_item tr);
  extern virtual function void write_sub3_tlcrossbar(axi4_vip_item tr);
  extern virtual function void write_sub4_dram(axi4_vip_item tr);

  extern protected function void check_subordinate_arrival(axi4_vip_item act, string sub_id);
  extern virtual function void check_phase(uvm_phase phase);

endclass : top_chip_dv_axi_scoreboard

function top_chip_dv_axi_scoreboard::new(string name, uvm_component parent);
  super.new(name, parent);
  mgr0_cva6_imp       = new("mgr0_cva6_imp", this);
  sub0_romctrlmem_imp = new("sub0_romctrlmem_imp", this);
  sub1_sram_imp       = new("sub1_sram_imp", this);
  sub2_mailbox_imp    = new("sub2_mailbox_imp", this);
  sub3_tlcrossbar_imp = new("sub3_tlcrossbar_imp", this);
  sub4_dram_imp       = new("sub4_dram_imp", this);
endfunction : new

function void top_chip_dv_axi_scoreboard::build_phase(uvm_phase phase);
  super.build_phase(phase);

  add_mem_range("sub0_romctrlmem", top_pkg::RomCtrlMemBase, top_pkg::RomCtrlMemLength);
  add_mem_range("sub1_sram", top_pkg::SRAMBase, top_pkg::SRAMLength);
  add_mem_range("sub2_mailbox", top_pkg::MailboxBase, top_pkg::MailboxLength);
  add_mem_range("sub3_tlcrossbar", top_pkg::TlCrossbarBase, top_pkg::TlCrossbarLength);
  add_mem_range("sub4_dram", top_pkg::DRAMBase, top_pkg::DRAMUsableLength);
endfunction : build_phase

function void top_chip_dv_axi_scoreboard::add_mem_range(string name,
                                                        bit [63:0] start_addr,
                                                        bit [63:0] addr_size);
  bit [63:0] end_addr = start_addr + addr_size - 1;
  mem_map.push_back('{name, start_addr, end_addr});
endfunction : add_mem_range

function top_chip_dv_axi_scoreboard::masked_id_t
  top_chip_dv_axi_scoreboard::get_masked_id(bit [63:0] raw_id);
  bit [63:0] mask = (64'(1) << top_pkg::AxiIdWidth) - 1;
  return masked_id_t'(raw_id & mask);
endfunction : get_masked_id

function string top_chip_dv_axi_scoreboard::addr_to_mem_range(bit [63:0] addr);
  foreach (mem_map[i]) begin
    if (addr >= mem_map[i].start_addr && addr <= mem_map[i].end_addr) begin
      return mem_map[i].subordinate_name;
    end
  end
  return default_subordinate_id;
endfunction : addr_to_mem_range

function void top_chip_dv_axi_scoreboard::perform_comparison(axi4_vip_item exp,
                                                             axi4_vip_item act,
                                                             string sub);
  masked_id_t mid = get_masked_id((act.dir == AXI_WRITE) ? act.bid : act.rid);

  if (act.dir == AXI_WRITE) begin
    if (act.awaddr  !== exp.awaddr  || act.awlen   !== exp.awlen  ||
        act.awsize  !== exp.awsize  || act.awburst !== exp.awburst) begin
      `uvm_error("SCB_ATTR_WR",
                 $sformatf({"Write attribute mismatch on %s ID:%h: ",
                             "act={addr:%h len:%h size:%h burst:%h} ",
                             "exp={addr:%h len:%h size:%h burst:%h}"},
                            sub, mid, act.awaddr, act.awlen, act.awsize, act.awburst,
                            exp.awaddr, exp.awlen, exp.awsize, exp.awburst))
    end
    if (act.wdata != exp.wdata) begin
      `uvm_error("SCB_WDATA",
                 $sformatf("Write data mismatch on %s ID:%h: act=%p exp=%p",
                           sub, mid, act.wdata, exp.wdata))
    end
    if (act.wstrb != exp.wstrb) begin
      `uvm_error("SCB_WSTRB",
                 $sformatf("Write strobe mismatch on %s ID:%h: act=%p exp=%p",
                           sub, mid, act.wstrb, exp.wstrb))
    end
  end else begin
    if (act.araddr  !== exp.araddr  || act.arlen   !== exp.arlen  ||
        act.arsize  !== exp.arsize  || act.arburst !== exp.arburst) begin
      `uvm_error("SCB_ATTR_RD",
                 $sformatf({"Read attribute mismatch on %s ID:%h: ",
                             "act={addr:%h len:%h size:%h burst:%h} ",
                             "exp={addr:%h len:%h size:%h burst:%h}"},
                            sub, mid, act.araddr, act.arlen, act.arsize, act.arburst,
                            exp.araddr, exp.arlen, exp.arsize, exp.arburst))
    end
    if (act.rdata != exp.rdata) begin
      `uvm_error("SCB_RDATA",
                 $sformatf("Read data mismatch on %s ID:%h: act=%p exp=%p",
                           sub, mid, act.rdata, exp.rdata))
    end
    if (act.rresp != exp.rresp) begin
      `uvm_error("SCB_RRESP",
                 $sformatf("Read response mismatch on %s ID:%h: act=%p exp=%p",
                           sub, mid, act.rresp, exp.rresp))
    end
  end
endfunction : perform_comparison

function void top_chip_dv_axi_scoreboard::write_mgr0_cva6(axi4_vip_item tr);
  bit    [63:0] addr = (tr.dir == AXI_WRITE) ? tr.awaddr : tr.araddr;
  bit    [63:0] raw_id = (tr.dir == AXI_WRITE) ? tr.awid : tr.arid;
  string        target_sub = addr_to_mem_range(addr);
  masked_id_t  mid = get_masked_id(raw_id);

  if (target_sub == default_subordinate_id) begin
    `uvm_error("SCB_ADDR_DECODE", $sformatf("Manager access to unmapped address: %h", addr))
  end else begin
    if (actual_queue[target_sub].exists(mid) && actual_queue[target_sub][mid].size() > 0) begin
      axi4_vip_item act_tr = actual_queue[target_sub][mid].pop_front();
      perform_comparison(tr, act_tr, target_sub);
    end else begin
      expected_queue[target_sub][mid].push_back(tr.item_clone());
    end
  end
endfunction : write_mgr0_cva6

function void top_chip_dv_axi_scoreboard::check_subordinate_arrival(axi4_vip_item act,
                                                                    string sub_id);
  masked_id_t mid = get_masked_id((act.dir == AXI_WRITE) ? act.bid : act.rid);

  if (expected_queue[sub_id].exists(mid) && expected_queue[sub_id][mid].size() > 0) begin
    axi4_vip_item exp_tr = expected_queue[sub_id][mid].pop_front();
    perform_comparison(exp_tr, act, sub_id);
  end else begin
    actual_queue[sub_id][mid].push_back(act.item_clone());
  end
endfunction : check_subordinate_arrival

function void top_chip_dv_axi_scoreboard::write_sub0_romctrlmem(axi4_vip_item tr);
  check_subordinate_arrival(tr, "sub0_romctrlmem");
endfunction : write_sub0_romctrlmem

function void top_chip_dv_axi_scoreboard::write_sub1_sram(axi4_vip_item tr);
  check_subordinate_arrival(tr, "sub1_sram");
endfunction : write_sub1_sram

function void top_chip_dv_axi_scoreboard::write_sub2_mailbox(axi4_vip_item tr);
  check_subordinate_arrival(tr, "sub2_mailbox");
endfunction : write_sub2_mailbox

function void top_chip_dv_axi_scoreboard::write_sub3_tlcrossbar(axi4_vip_item tr);
  check_subordinate_arrival(tr, "sub3_tlcrossbar");
endfunction : write_sub3_tlcrossbar

function void top_chip_dv_axi_scoreboard::write_sub4_dram(axi4_vip_item tr);
  check_subordinate_arrival(tr, "sub4_dram");
endfunction : write_sub4_dram

function void top_chip_dv_axi_scoreboard::check_phase(uvm_phase phase);
  super.check_phase(phase);

  foreach (expected_queue[s, i]) begin
    if (expected_queue[s][i].size() > 0) begin
      `uvm_error("SCB_DRAIN_DROP", $sformatf("DROPPED: Manager request for %s (ID %h) lost", s, i))
    end
  end

  foreach (actual_queue[s, i]) begin
    if (actual_queue[s][i].size() > 0) begin
      `uvm_error("SCB_DRAIN_GHOST",
                 $sformatf("GHOST: Subordinate %s (ID %h) responded without a manager request",
                           s, i))
    end
  end
endfunction : check_phase
