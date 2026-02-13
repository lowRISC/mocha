// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_uart_base_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_uart_base_vseq)

  uart_agent_pkg::baud_rate_e uart_baud_rate = uart_agent_pkg::BaudRate1Mbps;

  // Local queue for holding received UART TX data.
  byte uart_tx_data_q[$];

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();

  // Class specific methods
  extern function void configure_uart_agent(bit enable,
                                            bit enable_tx_monitor = 1'b1,
                                            bit enable_rx_monitor = 1'b0,
                                            bit en_parity = 1'b0,
                                            bit odd_parity = 1'b0,
                                            baud_rate_e baud_rate = uart_baud_rate);
  extern task get_uart_tx_items();
endclass : top_chip_dv_uart_base_vseq


function top_chip_dv_uart_base_vseq::new(string name="");
  super.new(name);
endfunction : new

task top_chip_dv_uart_base_vseq::body();
  super.body();
  `DV_WAIT(cfg.sw_test_status_vif.sw_test_status == SwTestStatusInTest);
  configure_uart_agent(.enable(1), .enable_rx_monitor(1));
endtask : body

// Configures and connects the UART agent for driving data over RX and receiving data on TX.
//
// Note that to fetch packets over the TX port, the get_uart_tx_items() task needs to be called
// separately as a forked thread in the test sequence.
//
// enable: 1: enable (configures and connects), 0: disable (disables sampling and disconnects)
// enable_tx_monitor: Enable sampling data on the TX port (default on).
// enable_rx_monitor: Enable sampling data on the RX port (default off).
// en_parity: Enable parity when driving RX traffic.
// odd_parity: Compute odd parity when driving RX traffic.
// baud_rate: The baud rate.
function void top_chip_dv_uart_base_vseq::configure_uart_agent(
                                           bit enable,
                                           bit enable_tx_monitor = 1'b1,
                                           bit enable_rx_monitor = 1'b0,
                                           bit en_parity = 1'b0,
                                           bit odd_parity = 1'b0,
                                           baud_rate_e baud_rate = uart_baud_rate);
  if (enable) begin
    `uvm_info(`gfn, "Configuring and connecting UART", UVM_LOW)
    p_sequencer.cfg.m_uart_agent_cfg.set_parity(en_parity, odd_parity);
    p_sequencer.cfg.m_uart_agent_cfg.set_baud_rate(baud_rate);
    p_sequencer.cfg.m_uart_agent_cfg.en_tx_monitor = enable_tx_monitor;
    p_sequencer.cfg.m_uart_agent_cfg.en_rx_monitor = enable_rx_monitor;
  end else begin
    `uvm_info(`gfn, "Disconnecting UART", UVM_LOW)
    p_sequencer.cfg.m_uart_agent_cfg.en_tx_monitor = 0;
    p_sequencer.cfg.m_uart_agent_cfg.en_rx_monitor = 0;
  end
endfunction : configure_uart_agent

// Grab packets sent by the DUT over the UART TX port
task top_chip_dv_uart_base_vseq::get_uart_tx_items();
  uart_item item;

  forever begin
    p_sequencer.uart_tx_fifo.get(item);
    `uvm_info(`gfn, $sformatf("Received UART data over TX:\n%0h", item.data), UVM_HIGH)
    uart_tx_data_q.push_back(item.data);
  end
endtask : get_uart_tx_items
