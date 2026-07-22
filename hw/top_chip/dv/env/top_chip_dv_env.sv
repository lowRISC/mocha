// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_env extends uvm_env;
  `uvm_component_utils(top_chip_dv_env)

  top_chip_dv_env_cfg cfg;

  top_chip_dv_virtual_sequencer top_vsqr;

  mem_bkdr_util mem_bkdr_util_h[chip_mem_e];

  // Agents
  i2c_agent  m_i2c_agent;
  uart_agent   m_uart_agent;
  // Passive AXI monitors on the xbar host (CVA6) + device ports; each self-gets its
  // cfg (is_active=UVM_PASSIVE) from the config_db published by its axi_vip_if in the tb.
  axi_mgr_agent m_mgr_axi[];
  axi_mgr_agent m_sub_axi[];

  top_chip_dv_axi_scoreboard m_axi_scb;

  // Standard SV/UVM methods
  extern function new(string name = "", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

  // Class specific methods
  extern task load_memories();

  // Block until every AXI manager monitor reports no in-flight transactions.
  extern task wait_for_axi_idle();
endclass : top_chip_dv_env


function top_chip_dv_env::new(string name = "", uvm_component parent = null);
  super.new(name, parent);
endfunction : new

function void top_chip_dv_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

  foreach (CHIP_MEM_LIST[i]) begin
    string inst = $sformatf("mem_bkdr_util[%0s]", CHIP_MEM_LIST[i].name());

    if (!uvm_config_db#(mem_bkdr_util)::get(this, "", inst, mem_bkdr_util_h[CHIP_MEM_LIST[i]])) begin
      `uvm_fatal(`gfn, {"failed to get ", inst, " from uvm_config_db"})
    end
  end

  // Get the handle to the SW log monitor (for compatible SW images)
  if (!uvm_config_db#(virtual sw_logger_if)::get(this, "", "sw_logger_vif", cfg.sw_logger_vif)) begin
    `uvm_fatal(`gfn, "failed to get sw_logger_vif from uvm_config_db")
  end

  // Get the GPIO VIF handle
  if (!uvm_config_db#(virtual pins_if #(NUM_GPIOS))::get(this, "", "gpio_vif", cfg.gpio_vif)) begin
    `uvm_fatal(`gfn, "Failed to retrieve gpio_vif from uvm_config_db")
  end

  // Initialize the sw logger interface.
  foreach (cfg.mem_image_files[i]) begin
    if (i inside {ChipMemSRAM}) begin
      cfg.sw_logger_vif.add_sw_log_db(cfg.mem_image_files[i]);
    end
  end

  cfg.sw_logger_vif.ready();

  // Get the handle to the SW test status monitor
  if (!uvm_config_db#(virtual sw_test_status_if)::get(this, "", "sw_test_status_vif", cfg.sw_test_status_vif)) begin
    `uvm_fatal(`gfn, "failed to get sw_test_status_vif from uvm_config_db")
  end

  if (!uvm_config_db#(virtual clk_rst_if)::get(this, "", "sys_clk_if", cfg.sys_clk_vif)) begin
    `uvm_fatal(`gfn, "Cannot get sys_clk_vif")
  end

  // Instantiate I2C agent
  m_i2c_agent = i2c_agent::type_id::create("m_i2c_agent", this);
  uvm_config_db#(i2c_agent_cfg)::set(this, "m_i2c_agent", "cfg", cfg.m_i2c_agent_cfg);

  // Instantiate UART agent
  m_uart_agent = uart_agent::type_id::create("m_uart_agent", this);
  uvm_config_db#(uart_agent_cfg)::set(this, "m_uart_agent*", "cfg", cfg.m_uart_agent_cfg);

  m_mgr_axi = new[top_pkg::AxiXbarHosts];
  m_mgr_axi[top_pkg::CVA6]    = axi_mgr_agent::type_id::create("m_mgr_axi_CVA6", this);
  m_mgr_axi[top_pkg::DM_HOST] = axi_mgr_agent::type_id::create("m_mgr_axi_DM_HOST", this);

  m_sub_axi = new[top_pkg::AxiXbarDevices];
  m_sub_axi[top_pkg::RomCtrlMem] = axi_mgr_agent::type_id::create("m_sub_axi_RomCtrlMem", this);
  m_sub_axi[top_pkg::SRAM]       = axi_mgr_agent::type_id::create("m_sub_axi_SRAM", this);
  m_sub_axi[top_pkg::DM_DEV]     = axi_mgr_agent::type_id::create("m_sub_axi_DM_DEV", this);
  m_sub_axi[top_pkg::Mailbox]    = axi_mgr_agent::type_id::create("m_sub_axi_Mailbox", this);
  m_sub_axi[top_pkg::RestOfChip] = axi_mgr_agent::type_id::create("m_sub_axi_RestOfChip", this);
  m_sub_axi[top_pkg::TlCrossbar] = axi_mgr_agent::type_id::create("m_sub_axi_TlCrossbar", this);
  m_sub_axi[top_pkg::DRAM]       = axi_mgr_agent::type_id::create("m_sub_axi_DRAM", this);

  m_axi_scb = top_chip_dv_axi_scoreboard::type_id::create("m_axi_scb", this);

  uvm_config_db#(top_chip_dv_env_cfg)::set(this, "", "cfg", cfg);

  top_vsqr                 = top_chip_dv_virtual_sequencer::type_id::create("top_vsqr", this);
  top_vsqr.cfg             = cfg;
  top_vsqr.mem_bkdr_util_h = mem_bkdr_util_h;
endfunction : build_phase

function void top_chip_dv_env::connect_phase(uvm_phase phase);
  super.connect_phase(phase);
  // Track specific agent sequencers in the virtual sequencer.
  // Allows virtual sequences to use the agents to drive RX items.
  top_vsqr.uart_sqr = m_uart_agent.sequencer;
  top_vsqr.i2c_sqr  = m_i2c_agent.sequencer;

  // Connect monitor output to matching FIFO in the virtual sequencer.
  // Allows virtual sequences to check TX items.
  m_uart_agent.monitor.tx_analysis_port.connect(top_vsqr.uart_tx_fifo.analysis_export);

  m_mgr_axi[top_pkg::CVA6].get_monitor().tx_ap.connect(m_axi_scb.mgr0_cva6_imp);
  m_mgr_axi[top_pkg::CVA6].get_monitor().aw_ap.connect(m_axi_scb.mgr0_cva6_req_imp);
  m_mgr_axi[top_pkg::CVA6].get_monitor().ar_ap.connect(m_axi_scb.mgr0_cva6_req_imp);
  m_mgr_axi[top_pkg::DM_HOST].get_monitor().tx_ap.connect(m_axi_scb.mgr1_dm_host_imp);
  m_mgr_axi[top_pkg::DM_HOST].get_monitor().aw_ap.connect(m_axi_scb.mgr1_dm_host_req_imp);
  m_mgr_axi[top_pkg::DM_HOST].get_monitor().ar_ap.connect(m_axi_scb.mgr1_dm_host_req_imp);
  m_sub_axi[top_pkg::RomCtrlMem].get_monitor().tx_ap.connect(m_axi_scb.sub0_romctrlmem_imp);
  m_sub_axi[top_pkg::SRAM].get_monitor().tx_ap.connect(m_axi_scb.sub1_sram_imp);
  m_sub_axi[top_pkg::Mailbox].get_monitor().tx_ap.connect(m_axi_scb.sub2_mailbox_imp);
  m_sub_axi[top_pkg::TlCrossbar].get_monitor().tx_ap.connect(m_axi_scb.sub3_tlcrossbar_imp);
  m_sub_axi[top_pkg::DRAM].get_monitor().tx_ap.connect(m_axi_scb.sub4_dram_imp);
  m_sub_axi[top_pkg::DM_DEV].get_monitor().tx_ap.connect(m_axi_scb.sub5_dm_dev_imp);
  m_sub_axi[top_pkg::RestOfChip].get_monitor().tx_ap.connect(m_axi_scb.sub6_restofchip_imp);

  // Flush the scoreboard on AXI fabric reset (all taps share it, so one reset monitor suffices).
  m_mgr_axi[top_pkg::CVA6].get_reset_monitor().m_analysis_port.connect(m_axi_scb.reset_imp);
endfunction : connect_phase

task top_chip_dv_env::load_memories();
  foreach (cfg.mem_image_files[m]) begin
    if (cfg.mem_image_files[m] != "") begin
      `uvm_info(`gfn, $sformatf("Initializing memory %s with image %s", m.name(), cfg.mem_image_files[m]), UVM_LOW)

      mem_bkdr_util_h[m].load_mem_from_file(cfg.mem_image_files[m]);
    end
  end
endtask : load_memories

task top_chip_dv_env::wait_for_axi_idle();
  foreach (m_mgr_axi[i]) begin
    if (m_mgr_axi[i] != null) m_mgr_axi[i].get_monitor().wait_for_idle();
  end
endtask : wait_for_axi_idle
