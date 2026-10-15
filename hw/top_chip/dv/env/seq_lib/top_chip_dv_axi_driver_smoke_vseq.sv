// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Basic smoke test which checks that the AXI driver replacing the CVA6 can write to and read back
// from a module on the xbar. There is no CPU, so the test ends when body() does rather than on a
// SW test status. The ROM is still loaded so rom_ctrl's boot-time check reads defined data.

class top_chip_dv_axi_driver_smoke_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_driver_smoke_vseq)

  typedef bit [top_pkg::AxiDataWidth-1:0] word_t;

  rand int unsigned num_words;
  // SRAM-relative byte offset of the first word.
  rand bit [63:0] base_offset;

  constraint num_words_c {
    num_words inside {[4:16]};
  }

  constraint base_offset_c {
    base_offset % top_pkg::AxiStrbWidth == 0;
    base_offset inside {[0 : top_pkg::SRAMLength - top_pkg::AxiStrbWidth * num_words]};
  }

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();

  // Class specific methods
  extern task write_word(bit [63:0] addr, word_t data);
  extern task read_word(bit [63:0] addr, output word_t data);
endclass : top_chip_dv_axi_driver_smoke_vseq

function top_chip_dv_axi_driver_smoke_vseq::new(string name = "");
  super.new(name);
  do_wait_for_sw_test_done = 1'b0;
endfunction : new

task top_chip_dv_axi_driver_smoke_vseq::body();
  word_t exp_data[];

  super.body();
  `DV_CHECK_NE_FATAL(p_sequencer.cva6_axi_sqr, null,
                     "Needs the axi_driver_to_cva6_bridge build mode")
  // The driver's reset (the chip's main reset) deasserts well after the top-level reset.
  `DV_WAIT(p_sequencer.cva6_axi_sqr.m_vif.u_clk_rst_if.rst_n === 1'b1,
           "CVA6 AXI driver reset never deasserted")

  // Write random words to SRAM, then read them back and check them.
  `uvm_info(`gfn, $sformatf("Writing %0d words to SRAM at offset 0x%0h", num_words, base_offset),
            UVM_LOW)
  exp_data = new[num_words];
  foreach (exp_data[i]) begin
    word_t data;
    `DV_CHECK_STD_RANDOMIZE_FATAL(data)
    exp_data[i] = data;
    write_word(top_pkg::SRAMBase + base_offset + top_pkg::AxiStrbWidth * i, exp_data[i]);
  end

  foreach (exp_data[i]) begin
    bit [63:0] addr = top_pkg::SRAMBase + base_offset + top_pkg::AxiStrbWidth * i;
    word_t     act_data;
    read_word(addr, act_data);
    `DV_CHECK_EQ(act_data, exp_data[i], $sformatf("read back from 0x%0h", addr))
  end
endtask : body

task top_chip_dv_axi_driver_smoke_vseq::write_word(bit [63:0] addr, word_t data);
  axi_single_write_seq seq = axi_single_write_seq::type_id::create("write_word");

  // The sequence takes its address, size, ID and USER limits from the bus.
  seq.set_bus_properties(p_sequencer.cva6_axi_sqr.m_vif);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_req.m_addr  == local::addr;
                                 m_req.m_size  == seq.m_max_size;
                                 m_req.m_burst == BurstIncr;
                                 m_req.m_lock  == 1'b0;
                                 m_req.m_user  == '0;
                                 m_wdata       == local::data;)
  seq.start(p_sequencer.cva6_axi_sqr);

  `DV_CHECK_EQ_FATAL(seq.m_responses.size(), 1, $sformatf("B responses to write to 0x%0h", addr))
  `DV_CHECK_EQ(seq.m_responses[0].m_resp, RespOkay, $sformatf("BRESP for write to 0x%0h", addr))
endtask : write_word

task top_chip_dv_axi_driver_smoke_vseq::read_word(bit [63:0] addr, output word_t data);
  axi_single_read_seq seq = axi_single_read_seq::type_id::create("read_word");

  seq.set_bus_properties(p_sequencer.cva6_axi_sqr.m_vif);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_req.m_addr  == local::addr;
                                 m_req.m_size  == seq.m_max_size;
                                 m_req.m_burst == BurstIncr;
                                 m_req.m_lock  == 1'b0;
                                 m_req.m_user  == '0;)
  seq.start(p_sequencer.cva6_axi_sqr);

  `DV_CHECK_EQ_FATAL(seq.m_responses.size(), 1, $sformatf("beats for read from 0x%0h", addr))
  `DV_CHECK_EQ(seq.m_responses[0].m_resp, RespOkay, $sformatf("RRESP for read from 0x%0h", addr))
  data = seq.m_responses[0].m_rdata[top_pkg::AxiDataWidth-1:0];
endtask : read_word
