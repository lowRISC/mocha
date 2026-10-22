// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Base for tests that drive the xbar's CVA6 host port from the AXI driver. Needs the
// axi_driver_to_cva6_bridge build mode. There is no CPU, so the test ends when body() does rather
// than on a SW test status.

class top_chip_dv_axi_driver_base_vseq extends top_chip_dv_base_vseq;
  `uvm_object_utils(top_chip_dv_axi_driver_base_vseq)

  // Consecutive cycles the driver's reset must stay deasserted before traffic starts.
  localparam int unsigned ResetStableCycles = 20;
  localparam int unsigned ResetTimeoutCycles = 10_000;

  // Standard SV/UVM methods
  extern function new(string name="");
  extern task body();
  extern task post_start();

  // Class specific methods
  //
  // Wait until the driver's reset (the chip's main reset) has settled. It deasserts well after the
  // top-level reset, and glitches on the way.
  extern task wait_for_axi_driver_reset();
  // Single-beat 8-byte write and read. They return the response for the caller to check.
  extern task write_word(bit [63:0] addr, bit [63:0] data, output axi_resp_e resp);
  extern task read_word(bit [63:0] addr, output bit [63:0] data, output axi_resp_e resp);
  // Write a random word at addr and read it back: both accesses must get OKAY and the data must
  // survive the round trip.
  extern task check_round_trip(bit [63:0] addr);
  // A write and a read at addr must both be answered with DECERR. The crossbar has no default
  // port (en_default_mst_port_i is tied off), so an address outside every rule is answered by its
  // own error subordinate and reaches no device port.
  extern task check_decerr(bit [63:0] addr);
endclass : top_chip_dv_axi_driver_base_vseq

function top_chip_dv_axi_driver_base_vseq::new(string name = "");
  super.new(name);
endfunction : new

task top_chip_dv_axi_driver_base_vseq::body();
  super.body();
  `DV_CHECK_NE_FATAL(p_sequencer.cva6_axi_agent, null,
                     "Needs the axi_driver_to_cva6_bridge build mode")
  wait_for_axi_driver_reset();
endtask : body

task top_chip_dv_axi_driver_base_vseq::post_start();
  // Skip the base wait_for_sw_test_done(): no SW runs.
endtask : post_start

task top_chip_dv_axi_driver_base_vseq::wait_for_axi_driver_reset();
  axi_vif_t    axi_vif = p_sequencer.cva6_axi_agent.get_vif();
  int unsigned stable = 0;
  int unsigned waited = 0;

  while (stable < ResetStableCycles) begin
    cfg.sys_clk_vif.wait_clks(1);
    if (++waited > ResetTimeoutCycles) begin
      `uvm_fatal(`gfn, "CVA6 AXI driver reset never stayed deasserted")
    end
    stable = (axi_vif.u_clk_rst_if.rst_n === 1'b1) ? (stable + 1) : 0;
  end
endtask : wait_for_axi_driver_reset

task top_chip_dv_axi_driver_base_vseq::write_word(bit [63:0] addr, bit [63:0] data,
                                                  output axi_resp_e resp);
  axi_single_write_seq seq = axi_single_write_seq::type_id::create("write_word");

  // The sequence takes its address, size, ID and USER limits from the bus.
  seq.set_bus_properties(p_sequencer.cva6_axi_agent.get_vif());
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_req.m_addr  == local::addr;
                                 m_req.m_size  == 3'd3;
                                 m_req.m_burst == BurstFixed;
                                 m_req.m_lock  == 1'b0;
                                 m_req.m_user  == '0;
                                 m_wdata       == local::data;
                                 m_wstrb       == 8'hFF;)
  seq.start(p_sequencer.cva6_axi_agent.get_sequencer());

  `DV_CHECK_EQ_FATAL(seq.m_responses.size(), 1,
                     $sformatf("B responses to write to 0x%0h (reset?)", addr))
  resp = axi_resp_e'(seq.m_responses[0].m_resp);
endtask : write_word

task top_chip_dv_axi_driver_base_vseq::read_word(bit [63:0] addr, output bit [63:0] data,
                                                 output axi_resp_e resp);
  axi_single_read_seq seq = axi_single_read_seq::type_id::create("read_word");

  seq.set_bus_properties(p_sequencer.cva6_axi_agent.get_vif());
  `DV_CHECK_RANDOMIZE_WITH_FATAL(seq,
                                 m_req.m_addr  == local::addr;
                                 m_req.m_size  == 3'd3;
                                 m_req.m_burst == BurstFixed;
                                 m_req.m_lock  == 1'b0;
                                 m_req.m_user  == '0;)
  seq.start(p_sequencer.cva6_axi_agent.get_sequencer());

  `DV_CHECK_EQ_FATAL(seq.m_responses.size(), 1,
                     $sformatf("beats for read from 0x%0h (reset?)", addr))
  data = seq.m_responses[0].m_rdata[63:0];
  resp = axi_resp_e'(seq.m_responses[0].m_resp);
endtask : read_word

task top_chip_dv_axi_driver_base_vseq::check_round_trip(bit [63:0] addr);
  bit [63:0] wdata = {$urandom, $urandom};
  bit [63:0] rdata;
  axi_resp_e bresp, rresp;

  write_word(addr, wdata, bresp);
  `DV_CHECK_EQ(bresp, RespOkay, $sformatf("BRESP for 0x%0h", addr))
  read_word(addr, rdata, rresp);
  `DV_CHECK_EQ(rresp, RespOkay, $sformatf("RRESP for 0x%0h", addr))
  `DV_CHECK_EQ(rdata, wdata, $sformatf("read back from 0x%0h", addr))
endtask : check_round_trip

task top_chip_dv_axi_driver_base_vseq::check_decerr(bit [63:0] addr);
  bit [63:0] rdata;
  axi_resp_e bresp, rresp;

  write_word(addr, {$urandom, $urandom}, bresp);
  `DV_CHECK_EQ(bresp, RespDecerr, $sformatf("BRESP for unmapped write to 0x%0h", addr))
  read_word(addr, rdata, rresp);
  `DV_CHECK_EQ(rresp, RespDecerr, $sformatf("RRESP for unmapped read from 0x%0h", addr))
endtask : check_decerr
