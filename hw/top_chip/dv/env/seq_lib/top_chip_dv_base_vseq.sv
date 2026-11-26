// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_base_vseq extends uvm_sequence;
  `uvm_object_utils(top_chip_dv_base_vseq)
  `uvm_declare_p_sequencer(top_chip_dv_virtual_sequencer)

  // Handles for ease of operation
  top_chip_dv_env_cfg cfg;
  top_chip_dv_env_cov cov;

  // Knobs to enable pre_start routines
  bit do_dut_init       = 1'b1;
  bit do_apply_reset    = 1'b1;

  // Knob to enable post_start routines
  bit do_wait_for_sw_test_done = 1'b1;

  // Knob to sample uart_tx_o once SW is in the test, keeping every byte in uart_tx_data_q and
  // logging every line under the UART_TRACE ID. It takes effect in a body() that calls
  // super.body().
  //
  // new() reads +do_uart_tx_log into it, so a derived vseq that needs a given value sets it in its
  // own new().
  bit do_uart_tx_log = 1'b0;

  // Baud rate SW programs into the console UART, BAUD_RATE in sw/device/lib/hal/uart.h
  protected baud_rate_e uart_baud_rate = BaudRate1Mbps;

  // Bytes the DUT has sent on uart_tx_o since SW entered the test, kept when do_uart_tx_log is set
  protected byte uart_tx_data_q[$];

  // Line SW is printing on uart_tx_o, logged when its newline arrives
  local string uart_tx_line_buf = "";

  // Standard SV/UVM methods
  extern function new(string name = "");
  // Wait for SW to enter the test and start sampling uart_tx_o, if do_uart_tx_log is set
  //
  // A derived body() that calls this first therefore starts once SW is in the test.
  extern task body();
  extern task pre_start();
  extern task post_start();

  // Class specific methods
  extern function void set_handles();
  extern virtual task dut_init(string reset_kind = "HARD");
  extern task apply_reset(string kind = "HARD");
  extern task wait_for_sw_test_done();
  // Set the baud rate, parity and monitors of the UART agent
  //
  // Called by body() when do_uart_tx_log is set.
  //
  //    enable:            1 applies the arguments below, 0 turns both monitors off
  //    enable_tx_monitor: Sample data on the TX port
  //    enable_rx_monitor: Sample data on the RX port
  //    en_parity:         Enable parity when driving RX traffic
  //    odd_parity:        Compute odd parity when driving RX traffic
  //    baud_rate:         The baud rate
  extern protected function void configure_uart_agent(bit enable,
                                                      bit enable_tx_monitor = 1'b1,
                                                      bit enable_rx_monitor = 1'b0,
                                                      bit en_parity = 1'b0,
                                                      bit odd_parity = 1'b0,
                                                      baud_rate_e baud_rate = uart_baud_rate);
  // Collect the bytes the DUT sends on uart_tx_o into uart_tx_data_q and log each complete line
  extern local task get_uart_tx_items();
  // Backdoor-read or override a const symbol in SW to modify the behavior of the test.
  // In the extended test vseq, add this function call to the start of body().
  extern function void sw_symbol_backdoor_access(input string symbol,
                                                 inout bit [7:0] data[],
                                                 input chip_mem_e mem = ChipMemDRAM,
                                                 input bit does_not_exist_ok = 0,
                                                 input bit is_write = 0);
  // Backdoor-read a const symbol in SW to make decisions based on SW constants.
  // Wrapper function for reads via sw_symbol_backdoor_access.
  extern function void sw_symbol_backdoor_read(input string symbol,
                                               inout bit [7:0] data[],
                                               input chip_mem_e mem = ChipMemDRAM,
                                               input bit does_not_exist_ok = 0);
  // Backdoor-override a const symbol in SW to modify the behavior of the test.
  // Wrapper function for writes via sw_symbol_backdoor_access.
  extern function void sw_symbol_backdoor_overwrite(input string symbol,
                                                    input bit [7:0] data[],
                                                    input chip_mem_e mem = ChipMemDRAM,
                                                    input bit does_not_exist_ok = 0);
  // General-use function to backdoor write a byte of data to any selected memory type
  extern function void mem_bkdr_write8(input chip_mem_e mem,
                                       input bit [bus_params_pkg::BUS_AW-1:0] addr,
                                       input byte data);
  // General-use function to backdoor read a byte of data from any selected memory type
  extern function void mem_bkdr_read8(input chip_mem_e mem,
                                      input bit [bus_params_pkg::BUS_AW-1:0] addr,
                                      output byte data);
endclass : top_chip_dv_base_vseq


function top_chip_dv_base_vseq::new(string name = "");
  super.new(name);
  void'($value$plusargs("do_uart_tx_log=%0b", do_uart_tx_log));
endfunction : new

task top_chip_dv_base_vseq::body();
  if (do_uart_tx_log) begin
    `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);
    configure_uart_agent(.enable(1), .enable_rx_monitor(1));
    fork
      get_uart_tx_items();
    join_none
  end
endtask : body

task top_chip_dv_base_vseq::pre_start();
  super.pre_start();
  if (cfg == null) set_handles();
  if (do_dut_init) dut_init("HARD");
endtask : pre_start

task top_chip_dv_base_vseq::post_start();
  super.post_start();
  if (do_wait_for_sw_test_done) wait_for_sw_test_done();
endtask : post_start

function void top_chip_dv_base_vseq::set_handles();
  `DV_CHECK_NE_FATAL(p_sequencer, null, "Did you forget to call `set_sequencer()`?")
  cfg = p_sequencer.cfg;
  cov = p_sequencer.cov;
endfunction : set_handles

task top_chip_dv_base_vseq::dut_init(string reset_kind = "HARD");
  if (do_apply_reset) begin
    apply_reset(reset_kind);
  end
endtask : dut_init

task top_chip_dv_base_vseq::apply_reset(string kind = "HARD");
  if (kind == "HARD") begin
    fork
      begin : isolation_fork
        fork
          cfg.sys_clk_vif.apply_reset();
        join_none
        wait fork;
      end : isolation_fork
    join
  end
endtask : apply_reset

task top_chip_dv_base_vseq::wait_for_sw_test_done();
  `uvm_info(`gfn, "Waiting for software to signal test end", UVM_LOW);
  fork
    begin : isolation_thread
      fork
        begin
          // Nice case - test status interface completion signal
          wait (p_sequencer.cfg.sw_test_status_vif.sw_test_done);
          // Pass/Fail message output by sw_test_status_vif
        end
      join_any
      disable fork;
    end : isolation_thread
  join
endtask : wait_for_sw_test_done

function void top_chip_dv_base_vseq::configure_uart_agent(bit enable,
                                                         bit enable_tx_monitor = 1'b1,
                                                         bit enable_rx_monitor = 1'b0,
                                                         bit en_parity = 1'b0,
                                                         bit odd_parity = 1'b0,
                                                         baud_rate_e baud_rate = uart_baud_rate);
  if (enable) begin
    `uvm_info(`gfn, "Configuring the UART agent", UVM_LOW)
    p_sequencer.cfg.m_uart_agent_cfg.set_parity(en_parity, odd_parity);
    p_sequencer.cfg.m_uart_agent_cfg.set_baud_rate(baud_rate);
    p_sequencer.cfg.m_uart_agent_cfg.en_tx_monitor = enable_tx_monitor;
    p_sequencer.cfg.m_uart_agent_cfg.en_rx_monitor = enable_rx_monitor;
  end else begin
    `uvm_info(`gfn, "Turning the UART agent monitors off", UVM_LOW)
    p_sequencer.cfg.m_uart_agent_cfg.en_tx_monitor = 0;
    p_sequencer.cfg.m_uart_agent_cfg.en_rx_monitor = 0;
  end
endfunction : configure_uart_agent

task top_chip_dv_base_vseq::get_uart_tx_items();
  uart_item item;

  forever begin
    p_sequencer.uart_tx_fifo.get(item);
    if (item.data == "\n") begin
      `uvm_info("UART_TRACE",
                $sformatf("Received UART data over TX: %0s", uart_tx_line_buf),
                UVM_LOW)
      uart_tx_line_buf = "";
    end else if (item.data == 8'h0d) begin
      // Discard carriage returns from \r\n line endings
    end else if (item.data inside {[8'h20:8'h7e]}) begin
      uart_tx_line_buf = {uart_tx_line_buf, string'(item.data)};
    end else begin
      uart_tx_line_buf = {uart_tx_line_buf, $sformatf("\\x%02h", item.data)};
    end
    uart_tx_data_q.push_back(item.data);
  end
endtask : get_uart_tx_items

function void top_chip_dv_base_vseq::sw_symbol_backdoor_access(
  input string symbol,
  inout bit [7:0] data[],
  input chip_mem_e mem = ChipMemDRAM,
  input bit does_not_exist_ok = 0,
  input bit is_write = 0);

  bit [bus_params_pkg::BUS_AW-1:0] addr, mem_addr;
  uint   size;
  uint   addr_mask;
  string sw_dir;
  string sw_basename;
  string image;
  bit    ret;

  `DV_CHECK_FATAL(mem inside {CHIP_MEM_LIST},
      $sformatf("SW symbol %0s is not expected to appear in %0s mem", symbol, mem))

  // Elf file name checks.
  `DV_CHECK_FATAL(p_sequencer.cfg.mem_image_files.exists(mem))
  `DV_CHECK_STRNE_FATAL(p_sequencer.cfg.mem_image_files[mem], "")

  // Find the symbol in the sw elf file.
  sw_dir      = str_utils_pkg::str_path_dirname(.filename(p_sequencer.cfg.mem_image_files[mem]));
  sw_basename = str_utils_pkg::str_path_basename(.filename(p_sequencer.cfg.mem_image_files[mem]), .drop_extn(1'b1));
  image       = {sw_dir, "/", sw_basename};
  ret         = dv_utils_pkg::sw_symbol_get_addr_size(image, symbol, does_not_exist_ok, addr, size);
  if (!ret) begin
    string msg = $sformatf("Failed to find symbol %0s in %0s", symbol, image);
    if (does_not_exist_ok) begin
      `uvm_info(`gfn, msg, UVM_LOW)
      return;
    end else begin
      `uvm_fatal(`gfn, msg)
    end
  end
  `DV_CHECK_EQ_FATAL(size, data.size())

  addr_mask = (2**$clog2(p_sequencer.mem_bkdr_util_h[mem].get_size_bytes()))-1;
  mem_addr = addr & addr_mask;

  if (is_write) begin
    `uvm_info(`gfn, $sformatf({
                                "Overwriting symbol \"%s\" via backdoor in %0s: ",
                                "abs addr = 0x%0h, mem addr = 0x%0h, size = %0d, ",
                                "addr_mask = 0x%0h"
                              }, symbol, mem, addr, mem_addr, size, addr_mask), UVM_LOW)
    for (int i = 0; i < size; i++) begin
      mem_bkdr_write8(mem, mem_addr + i, data[i]);
    end
  end else begin
    `uvm_info(`gfn, $sformatf({
                                "Reading symbol \"%s\" via backdoor in %0s: ",
                                "abs addr = 0x%0h, mem addr = 0x%0h, size = %0d, ",
                                "addr_mask = 0x%0h"
                              }, symbol, mem, addr, mem_addr, size, addr_mask), UVM_LOW)
    for (int i = 0; i < size; i++) begin
      mem_bkdr_read8(mem, mem_addr + i, data[i]);
    end
  end
endfunction : sw_symbol_backdoor_access

function void top_chip_dv_base_vseq::sw_symbol_backdoor_read(input string symbol,
                                              inout bit [7:0] data[],
                                              input chip_mem_e mem = ChipMemDRAM,
                                              input bit does_not_exist_ok = 0);

  sw_symbol_backdoor_access(symbol, data, mem, does_not_exist_ok, 0);
  `uvm_info(`gfn, $sformatf("sw_symbol_backdoor_read gets %p", data), UVM_MEDIUM)
endfunction : sw_symbol_backdoor_read

function void top_chip_dv_base_vseq::sw_symbol_backdoor_overwrite(input string symbol,
                                                   input bit [7:0] data[],
                                                   input chip_mem_e mem = ChipMemDRAM,
                                                   input bit does_not_exist_ok = 0);

  sw_symbol_backdoor_access(symbol, data, mem, does_not_exist_ok, 1);
endfunction : sw_symbol_backdoor_overwrite

function void top_chip_dv_base_vseq::mem_bkdr_write8(input chip_mem_e mem,
                                      input bit [bus_params_pkg::BUS_AW-1:0] addr,
                                      input byte data);
  byte prev_data;
  if (mem inside {ChipMemSRAM, ChipMemDRAM}) begin
    prev_data = p_sequencer.mem_bkdr_util_h[mem].read8(addr);
    p_sequencer.mem_bkdr_util_h[mem].write8(addr, data);
  end else begin
    `dv_fatal($sformatf("Backdoor %0s access not yet supported", mem.name()))
  end
  `uvm_info(`gfn, $sformatf("addr %0h = 0x%0h --> 0x%0h", addr, prev_data, data), UVM_HIGH)
endfunction : mem_bkdr_write8

function void top_chip_dv_base_vseq::mem_bkdr_read8(input chip_mem_e mem,
                                     input bit [bus_params_pkg::BUS_AW-1:0] addr,
                                     output byte data);
  if (mem inside {ChipMemSRAM, ChipMemDRAM}) begin
    data = p_sequencer.mem_bkdr_util_h[mem].read8(addr);
  end else begin
    `dv_fatal($sformatf("Backdoor %0s access not yet supported", mem.name()))
  end
  `uvm_info(`gfn, $sformatf("addr %0h = 0x%0h", addr, data), UVM_HIGH)
endfunction : mem_bkdr_read8
