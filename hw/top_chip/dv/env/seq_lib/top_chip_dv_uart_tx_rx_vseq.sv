// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Virtual sequence for the chip-level UART pin loopback test
//
// SW sends a byte sequence out of uart_tx_o with both internal loopbacks off. The UART agent echoes
// each of those bytes back onto uart_rx_i, closing the loopback outside the chip, and SW passes if
// it reads back what it sent.
class top_chip_dv_uart_tx_rx_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_uart_tx_rx_vseq)

  // Size of the tx_rx_data array in SW. sw_symbol_backdoor_overwrite() checks the two agree.
  localparam int unsigned MaxBytes = 32;

  // Number of bytes SW sends and the agent echoes, written to the tx_rx_byte_count SW symbol
  protected rand bit [7:0] byte_count[1];

  // Bytes written to the tx_rx_data SW symbol, of which SW sends the first byte_count
  protected rand bit [7:0] tx_rx_data[MaxBytes];

  // Number of bytes the agent has finished driving back onto uart_rx_i
  protected int unsigned num_echoed;

  extern constraint byte_count_c;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
  // Check that a SW pass came through the pins
  //
  // SW also passes when its bytes never leave the chip, for example with system loopback still on,
  // because then uart_tx_o stays high and nothing is echoed. The last echo may still be finishing
  // its stop bit when SW reports, so wait for it rather than compare at once.
  extern task post_start();

  // Methods extending base methods from top_chip_dv_base_vseq
  extern virtual task dut_init(string reset_kind = "HARD");
endclass : top_chip_dv_uart_tx_rx_vseq


constraint top_chip_dv_uart_tx_rx_vseq::byte_count_c {
  byte_count[0] inside {[1:MaxBytes]};
}

function top_chip_dv_uart_tx_rx_vseq::new(string name = "");
  super.new(name);
  // The echo in body() reads uart_tx_data_q
  do_uart_tx_log = 1'b1;
endfunction : new

task top_chip_dv_uart_tx_rx_vseq::body();
  super.body();

  `uvm_info(`gfn,
            $sformatf("Echoing %0d bytes from uart_tx_o onto uart_rx_i", byte_count[0]),
            UVM_LOW)
  // Fork the echo so that body() returns at once, as the base does for get_uart_tx_items(). When
  // +max_quit_count lets a SW failure run on, post_start() then ends the test as SW reports, where
  // a blocking echo would wait for the DV_WAIT below to time out on a byte SW never sent.
  //
  // uart_tx_data_q holds every byte the monitor has seen on uart_tx_o since SW started the test,
  // and SW prints nothing before its byte sequence.
  fork
    for (int unsigned i = 0; i < byte_count[0]; i++) begin
      uart_default_seq rx_seq = uart_default_seq::type_id::create("rx_seq");

      `DV_WAIT(uart_tx_data_q.size() > i,
               $sformatf("Timed out waiting for byte %0d on uart_tx_o", i))
      // uart_seq constrains the parity bit through p_sequencer, so set the sequencer before
      // randomizing
      rx_seq.set_sequencer(p_sequencer.uart_sqr);
      `DV_CHECK_RANDOMIZE_WITH_FATAL(rx_seq, data == local::uart_tx_data_q[i];)
      rx_seq.start(p_sequencer.uart_sqr, this);
      num_echoed++;
    end
  join_none
endtask : body

task top_chip_dv_uart_tx_rx_vseq::post_start();
  super.post_start();

  if (cfg.sw_test_status_vif.sw_test_status == SwTestStatusPassed) begin
    `DV_WAIT(num_echoed == byte_count[0],
             $sformatf("SW passed but only %0d of %0d bytes came back through the pins",
                       num_echoed, byte_count[0]))
  end
endtask : post_start

task top_chip_dv_uart_tx_rx_vseq::dut_init(string reset_kind = "HARD");
  super.dut_init(reset_kind);

  sw_symbol_backdoor_overwrite("tx_rx_byte_count", byte_count);
  sw_symbol_backdoor_overwrite("tx_rx_data", tx_rx_data);
endtask : dut_init
