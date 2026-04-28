// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_env extends uvm_env;
  `uvm_component_utils(top_chip_dv_env)

  top_chip_dv_env_cfg cfg;

  top_chip_dv_virtual_sequencer top_vsqr;

  mem_bkdr_util mem_bkdr_util_h[chip_mem_e];

  // Agents
  uart_agent m_uart_agent;

  // Standard SV/UVM methods
  extern function new(string name = "", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);

  // Class specific methods
  extern task load_memories();
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

  // Instantiate UART agent
  m_uart_agent = uart_agent::type_id::create("m_uart_agent", this);
  uvm_config_db#(uart_agent_cfg)::set(this, "m_uart_agent*", "cfg", cfg.m_uart_agent_cfg);

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

  // Connect monitor output to matching FIFO in the virtual sequencer.
  // Allows virtual sequences to check TX items.
  m_uart_agent.monitor.tx_analysis_port.connect(top_vsqr.uart_tx_fifo.analysis_export);
endfunction : connect_phase

task top_chip_dv_env::load_memories();
  foreach (cfg.mem_image_files[m]) begin
    if (cfg.mem_image_files[m] != "") begin
      `uvm_info(`gfn, $sformatf("Initializing memory %s with image %s", m.name(), cfg.mem_image_files[m]), UVM_LOW)

      mem_bkdr_util_h[m].load_mem_from_file(cfg.mem_image_files[m]);
    end
  end
endtask : load_memories
