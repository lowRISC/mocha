// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Basic smoke test which checks that the AXI driver replacing the CVA6 can write to and read back 
// from a module on the xbar. There is no CPU, so the test ends when body() does rather than on a
// SW test status.

class top_chip_dv_axi_driver_smoke_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_driver_smoke_vseq)

  // Consecutive cycles the driver's reset must stay deasserted before traffic starts.
  localparam int unsigned ResetStableCycles = 20;
  localparam int unsigned ResetTimeoutCycles = 10_000;

  rand int unsigned num_words;
  // SRAM-relative byte offset of the first word.
  rand bit [63:0] base_offset;

  constraint num_words_c {
    num_words inside {[4:16]};
  }

  constraint base_offset_c {
    base_offset[2:0] == 3'b0;
    base_offset + 8 * num_words <= top_pkg::SRAMLength;
  }

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
  extern task post_start();

  // Class specific methods
  //
  // Wait until the driver's reset (the chip's main reset) has settled. It deasserts well after the
  // top-level reset, and glitches on the way.
  extern task wait_for_axi_driver_reset();
  extern task write_word(bit [63:0] addr, bit [63:0] data);
  extern task read_word(bit [63:0] addr, output bit [63:0] data);
endclass : top_chip_dv_axi_driver_smoke_vseq

function top_chip_dv_axi_driver_smoke_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_axi_driver_smoke_vseq::body();
  bit [63:0] exp_data[];

  super.body();
  `DV_CHECK_NE_FATAL(p_sequencer.cva6_axi_agent, null,
                     "Needs the axi_driver_to_cva6_bridge build mode")
  wait_for_axi_driver_reset();

  // Write random words to SRAM, then read them back and check them.
  `uvm_info(`gfn, $sformatf("Writing %0d words to SRAM at offset 0x%0h", num_words, base_offset),
            UVM_LOW)
  exp_data = new[num_words];
  foreach (exp_data[i]) begin
    exp_data[i] = {$urandom, $urandom};
    write_word(top_pkg::SRAMBase + base_offset + 8 * i, exp_data[i]);
  end

  foreach (exp_data[i]) begin
    bit [63:0] addr = top_pkg::SRAMBase + base_offset + 8 * i;
    bit [63:0] act_data;
    read_word(addr, act_data);
    `DV_CHECK_EQ(act_data, exp_data[i], $sformatf("read back from 0x%0h", addr))
  end
endtask : body

task top_chip_dv_axi_driver_smoke_vseq::post_start();
  // Skip the base wait_for_sw_test_done(): no SW runs.
endtask : post_start

task top_chip_dv_axi_driver_smoke_vseq::wait_for_axi_driver_reset();
  axi_agent_cfg agent_cfg;
  int unsigned  stable = 0;
  int unsigned  waited = 0;

  // The agent keeps its cfg local, so fetch the one axi_vip_if published for it.
  if (!uvm_config_db#(axi_agent_cfg)::get(p_sequencer.cva6_axi_agent, "", "cfg", agent_cfg)) begin
    `uvm_fatal(`gfn, "Cannot get the CVA6 AXI agent cfg")
  end

  while (stable < ResetStableCycles) begin
    cfg.sys_clk_vif.wait_clks(1);
    if (++waited > ResetTimeoutCycles) begin
      `uvm_fatal(`gfn, "CVA6 AXI driver reset never stayed deasserted")
    end
    stable = (agent_cfg.clk_rst_vif.rst_n === 1'b1) ? (stable + 1) : 0;
  end
endtask : wait_for_axi_driver_reset

task top_chip_dv_axi_driver_smoke_vseq::write_word(bit [63:0] addr, bit [63:0] data);
  axi_mgr_write_burst_vseq seq = axi_mgr_write_burst_vseq::type_id::create("write_word");
  axi_write_data_item      beat = axi_write_data_item::type_id::create("beat");

  beat.m_data = data;
  beat.m_strb = 8'hFF;
  beat.m_user = '0;
  beat.m_last = 1'b1;
  seq.m_data_items.push_back(beat);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_aw_req.m_id    < (1 << top_pkg::AxiIdWidth);
                                 m_aw_req.m_addr  == local::addr;
                                 m_aw_req.m_size  == 3'd3;
                                 m_aw_req.m_burst == BurstFixed;
                                 m_aw_req.m_lock  == 1'b0;
                                 m_aw_req.m_user  == '0;)

  seq.set_write_response_router(p_sequencer.cva6_axi_agent.get_write_response_router());
  seq.set_sequencers(p_sequencer.cva6_axi_agent.get_write_request_sequencer(),
                     p_sequencer.cva6_axi_agent.get_write_data_sequencer(),
                     p_sequencer.cva6_axi_agent.get_write_response_sequencer());
  seq.start(null);

  `DV_CHECK_NE_FATAL(seq.rsp.m_write_response, null, "no write response (reset?)")
  `DV_CHECK_EQ(seq.rsp.m_write_response.m_resp, axi_write_response_item::BRespOkay,
               $sformatf("BRESP for write to 0x%0h", addr))
endtask : write_word

task top_chip_dv_axi_driver_smoke_vseq::read_word(bit [63:0] addr, output bit [63:0] data);
  axi_mgr_read_burst_vseq seq = axi_mgr_read_burst_vseq::type_id::create("read_word");

  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_ar_req.m_id    < (1 << top_pkg::AxiIdWidth);
                                 m_ar_req.m_addr  == local::addr;
                                 m_ar_req.m_len   == 8'd0;
                                 m_ar_req.m_size  == 3'd3;
                                 m_ar_req.m_burst == BurstFixed;
                                 m_ar_req.m_lock  == 1'b0;
                                 m_ar_req.m_user  == '0;)

  seq.set_read_response_router(p_sequencer.cva6_axi_agent.get_read_response_router());
  seq.set_sequencers(p_sequencer.cva6_axi_agent.get_read_request_sequencer(),
                     p_sequencer.cva6_axi_agent.get_read_data_sequencer());
  seq.start(null);

  `DV_CHECK_EQ_FATAL(seq.m_read_beats.size(), 1, $sformatf("beats for read from 0x%0h", addr))
  `DV_CHECK_EQ(seq.m_read_beats[0].m_resp, axi_read_data_item::RRespOkay,
               $sformatf("RRESP for read from 0x%0h", addr))
  data = seq.m_read_beats[0].m_data[63:0];
endtask : read_word
