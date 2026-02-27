// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

class top_chip_dv_spi_device_base_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_spi_device_base_vseq)

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task pre_start();
  extern task body();
endclass : top_chip_dv_spi_device_base_vseq


function top_chip_dv_spi_device_base_vseq::new(string name="");
  super.new(name);
endfunction : new

task top_chip_dv_spi_device_base_vseq::body();
  spi_device_seq m_device_seq;
  super.body();

  // Wait for reset before configuring
  p_sequencer.cfg.peri_clk_vif.wait_for_reset();

  // Create and start the spi_device sequence
  m_device_seq = spi_device_seq::type_id::create("m_device_seq");
  fork m_device_seq.start(p_sequencer.spi_device_sqr); join_none
endtask : body

task top_chip_dv_spi_device_base_vseq::pre_start();
  // Select the first Csb for communication.
  p_sequencer.cfg.m_spi_device_agent_cfg.csid = '0;

  // While the selection of this value seems arbitrary, it is not.
  // The spi agent has a concept of "transaction size" that is used by the
  // monitor / driver to determine how it should view the number of collected
  // bytes.
  // The value 4 is chosen because the corresponding C test case does the following:
  //   - Transmit 4 bytes
  //   - Transmit and receive N bytes
  //   - Receive 4 bytes
  // This sequence, when paired with the agent's 4 byte granularity playback,
  // works well as a smoke test case for spi host activity.
  p_sequencer.cfg.m_spi_device_agent_cfg.num_bytes_per_trans_in_mon = 4;

  // Setting the byte order to 0 ensures that the 4 byte transaction sent to
  // the agent from the DUT is played back in exactly the same order, thus
  // making things easy to compare.
  p_sequencer.cfg.m_spi_device_agent_cfg.byte_order = '0;
  super.pre_start();
endtask : pre_start
