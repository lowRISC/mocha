// Copyright lowRISC and contributors (COSMIC project).
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
  rand i2c_agent_cfg     m_i2c_agent_cfg;
  rand spi_agent_cfg     m_spi_host_agent_cfg;
  rand spi_agent_cfg     m_spi_device_agent_cfg;

  // Register model of the chip
  //
  // A frontdoor access through the model needs the testbench to drive the bus that CVA6 normally
  // drives. Tests that do this select the axi_driver_to_cva6_bridge build mode in
  // top_chip_sim_cfg.hjson, which defines SWAP_CVA6_WITH_AXI_DRIVER so that tb/tb_cfg.sv replaces
  // CVA6 with axi_driver_to_cva6_bridge, an AXI manager agent on the same ports. The environment
  // then connects the model to that agent. In the default build CVA6 runs software and only
  // backdoor accesses through the model work.
  top_chip_reg_block ral;

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

  // Create I2C agent config object
  m_i2c_agent_cfg = i2c_agent_cfg::type_id::create("m_i2c_agent_cfg");

  // Disable functional coverage collection for chip level
  m_i2c_agent_cfg.en_cov = 0;

  // Create the config object of the SPI agent driving the SPI device as an SPI host
  m_spi_host_agent_cfg         = spi_agent_cfg::type_id::create("m_spi_host_agent_cfg");
  m_spi_host_agent_cfg.if_mode = dv_utils_pkg::Host;
  m_spi_host_agent_cfg.en_cov  = 0;

  // Create the config object of the SPI agent answering the SPI host as an SPI device
  m_spi_device_agent_cfg         = spi_agent_cfg::type_id::create("m_spi_device_agent_cfg");
  m_spi_device_agent_cfg.if_mode = dv_utils_pkg::Device;
  m_spi_device_agent_cfg.en_cov  = 0;

  // The model holds absolute chip addresses, so it is built at base address 0
  ral = top_chip_reg_block::type_id::create("ral");
  ral.build(.base_addr(0), .csr_excl(null));
  ral.lock_model();
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
