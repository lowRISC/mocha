// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Answer the SPI host from the SPI device agent, which plays each 4-byte word it receives back to
// the host during the next word of the same transaction
//
// SW sends words and checks that it reads them back one word later.
class top_chip_dv_spi_host_smoke_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_spi_host_smoke_vseq)

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();
endclass : top_chip_dv_spi_host_smoke_vseq


function top_chip_dv_spi_host_smoke_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_spi_host_smoke_vseq::body();
  spi_device_seq echo_seq = spi_device_seq::type_id::create("echo_seq");

  super.body();

  // Play the bytes of each word back in the order they arrived, so SW reads back the word it sent.
  // The agent collects num_bytes_per_trans_in_mon bytes per word, 4 by default.
  cfg.m_spi_device_agent_cfg.byte_order = 0;

  fork
    echo_seq.start(p_sequencer.spi_device_sqr);
  join_none
endtask : body
