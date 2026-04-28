// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_env_cfg extends uvm_object;
  string mem_image_files[chip_mem_e];
  longint unsigned sys_timeout_cycles = 20_000_000;

  // External interfaces
  virtual clk_rst_if        sys_clk_vif;

  // GPIO Pads interface
  virtual pins_if #(NUM_GPIOS) gpio_vif;

  // Software logging & status interfaces
  virtual sw_logger_if      sw_logger_vif;
  virtual sw_test_status_if sw_test_status_vif;

  // External interface agent configs
  rand uart_agent_cfg    m_uart_agent_cfg;

  `uvm_object_utils_begin(top_chip_dv_env_cfg)
  `uvm_object_utils_end

  // Standard SV/UVM methods
  extern function new(string name = "");

  // Class specific methods
  extern function void initialize();
  extern function void get_mem_image_files_from_plusargs();
endclass : top_chip_dv_env_cfg


function top_chip_dv_env_cfg::new(string name = "");
  super.new(name);
endfunction : new

function void top_chip_dv_env_cfg::initialize();
  get_mem_image_files_from_plusargs();

  // Create UART agent config obj
  m_uart_agent_cfg               = uart_agent_cfg::type_id::create("m_uart_agent_cfg");
  // Do not create UART agent fcov in chip level test
  m_uart_agent_cfg.en_cov        = 0;
  // Configuration is required to perform meaningful monitoring
  m_uart_agent_cfg.en_tx_monitor = 0;
  m_uart_agent_cfg.en_rx_monitor = 0;
endfunction : initialize

function void top_chip_dv_env_cfg::get_mem_image_files_from_plusargs();
  foreach (CHIP_MEM_LIST[i]) begin
    string image_file;
    string plusarg;

    plusarg = $sformatf("%s_image_file=%%s", CHIP_MEM_LIST[i].name());
    `uvm_info(`gfn, $sformatf("Looking for image for memory %s with plus arg %s", CHIP_MEM_LIST[i].name(), plusarg), UVM_LOW);

    if ($value$plusargs(plusarg, image_file)) begin
      mem_image_files[CHIP_MEM_LIST[i]] = image_file;
      `uvm_info(`gfn, $sformatf("Got image file %s for memory %s",
        image_file, CHIP_MEM_LIST[i].name()), UVM_MEDIUM)
    end
  end
endfunction : get_mem_image_files_from_plusargs
