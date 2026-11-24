// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Start manager items between edges to check that handshakes use sampled VALID and READY (AMBA AXI
// H.c A3.2.1). With AWREADY, WREADY and ARREADY already high, each transfer must reach the bus and
// complete. Then start B and R accepts while their VALID is high. Require exactly one handshake and
// subsequent VALID low.

class axi_agent_off_edge_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_off_edge_vseq)

  // The number of transfers of each kind
  int unsigned m_num_rounds = 20;

  // Cycles after which a transfer that has not completed is reported as lost
  int unsigned m_watchdog_cycles = 2000;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Wait for a third of a clock period after the next rising edge
  extern protected task wait_off_edge();

  // Send a write or a read whose request reaches the drivers between edges
  extern protected task off_edge_request(bit is_write);

  // Send a write, wait for BVALID, then start the B accept between edges
  extern protected task off_edge_b_accept();

  // Send a single-beat read, wait for RVALID, then start the R accept between edges
  extern protected task off_edge_r_accept();
endclass : axi_agent_off_edge_vseq


function axi_agent_off_edge_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_off_edge_vseq::body();
  set_sub_ready(1'b0);
  need("b_handshakes", 2 * m_num_rounds);
  need("r_handshakes", 2 * m_num_rounds);

  repeat (m_num_rounds) begin
    off_edge_request(1'b1);
    off_edge_request(1'b0);
  end

  // Direct channel accepts have no axi_transfer_seq records for scoreboard comparison
  cfg.m_mgr_records = 1'b0;
  repeat (m_num_rounds) begin
    off_edge_b_accept();
    off_edge_r_accept();
  end
endtask : body

task axi_agent_off_edge_vseq::wait_off_edge();
  @(posedge cfg.clk_rst_vif.clk);
  #(cfg.clk_rst_vif.clk_period_ps * 1ps / 3);
endtask : wait_off_edge

task axi_agent_off_edge_vseq::off_edge_request(bit is_write);
  axi_agent_rand_req req;
  axi_transfer_seq   seq;

  wait_ready();
  req = new_req();
  wait_off_edge();
  fork
    begin : isolation_fork
      fork
        send(req, is_write, seq);
        begin
          cfg.clk_rst_vif.wait_clks(m_watchdog_cycles);
          `uvm_fatal(get_full_name(),
                     $sformatf("A %0s started between edges did not complete in %0d cycles.",
                               is_write ? "write" : "read", m_watchdog_cycles))
        end
      join_any
      disable fork;
    end
  join
endtask : off_edge_request

task axi_agent_off_edge_vseq::off_edge_b_accept();
  axi_mgr_agent                 agent = p_sequencer.m_mgr_agent;
  axi_vif_t                     vif = agent.get_vif();
  int unsigned                  bus_bytes = cfg.m_data_width / 8;
  axi_agent_rand_req            req;
  axi_mgr_txn_request_seq       aw_seq = axi_mgr_txn_request_seq::type_id::create("aw_seq");
  axi_mgr_write_listed_data_seq w_seq = axi_mgr_write_listed_data_seq::type_id::create("w_seq");
  axi_mgr_write_response_seq    b_seq = axi_mgr_write_response_seq::type_id::create("b_seq");
  int unsigned                  handshakes;

  wait_ready();
  req = new_req();
  aw_seq.m_req = req;
  for (int unsigned n = 0; n <= req.m_len; n++) begin
    axi_write_data_item       item = axi_write_data_item::type_id::create("item");
    bit [AxiMaxAddrWidth-1:0] beat_addr;
    int unsigned              lower, upper;

    axi_beat_lanes(req.m_addr, req.m_size, req.m_len, req.m_burst, bus_bytes, n, beat_addr,
                   lower, upper);
    item.m_data = '0;
    item.m_strb = '0;
    item.m_user = '0;
    for (int unsigned lane = lower; lane <= upper; lane++) begin
      item.m_data[8 * lane +: 8] = $urandom();
      item.m_strb[lane]          = 1'b1;
    end
    w_seq.m_items.push_back(item);
  end
  `DV_CHECK_RANDOMIZE_FATAL(w_seq)
  b_seq.m_use_fixed_ready_without_valid_pct = 1'b1;
  b_seq.m_fixed_ready_without_valid_pct     = 100;
  b_seq.m_use_fixed_valid_to_ready_delay    = 1'b1;
  b_seq.m_fixed_valid_to_ready_delay        = 0;

  fork
    aw_seq.start(agent.get_write_request_sequencer());
    w_seq.start(agent.get_write_data_sequencer());
  join
  while (vif.b_if.mon_cb.bvalid !== 1'b1) begin
    @(vif.b_if.mon_cb);
  end
  handshakes = cfg.m_probe_vif.m_b_handshakes;
  wait_off_edge();
  b_seq.start(agent.get_write_response_sequencer());
  cfg.clk_rst_vif.wait_clks(3);

  if (b_seq.rsp == null || cfg.m_probe_vif.m_b_handshakes != handshakes + 1 ||
      vif.b_if.bvalid !== 1'b0) begin
    `uvm_error(get_full_name(),
               $sformatf({"A B accept started between edges ended after %0d B handshakes, with ",
                          "BVALID %0b afterwards: it should take exactly one."},
                         cfg.m_probe_vif.m_b_handshakes - handshakes, vif.b_if.bvalid))
  end
endtask : off_edge_b_accept

task axi_agent_off_edge_vseq::off_edge_r_accept();
  axi_mgr_agent           agent = p_sequencer.m_mgr_agent;
  axi_vif_t               vif = agent.get_vif();
  axi_agent_rand_req      req = axi_agent_rand_req::type_id::create("req");
  axi_mgr_txn_request_seq ar_seq = axi_mgr_txn_request_seq::type_id::create("ar_seq");
  axi_mgr_read_data_seq   r_seq = axi_mgr_read_data_seq::type_id::create("r_seq");
  int unsigned            handshakes;

  wait_ready();
  req.set_bus(cfg);
  `DV_CHECK_RANDOMIZE_WITH_FATAL(req, m_len == 0;)
  ar_seq.m_req = req;
  r_seq.m_use_fixed_ready_without_valid_pct = 1'b1;
  r_seq.m_fixed_ready_without_valid_pct     = 100;
  r_seq.m_use_fixed_valid_to_ready_delay    = 1'b1;
  r_seq.m_fixed_valid_to_ready_delay        = 0;

  ar_seq.start(agent.get_read_request_sequencer());
  while (vif.r_if.mon_cb.rvalid !== 1'b1) begin
    @(vif.r_if.mon_cb);
  end
  handshakes = cfg.m_probe_vif.m_r_handshakes;
  wait_off_edge();
  r_seq.start(agent.get_read_data_sequencer());
  cfg.clk_rst_vif.wait_clks(3);

  if (r_seq.rsp == null || cfg.m_probe_vif.m_r_handshakes != handshakes + 1 ||
      vif.r_if.rvalid !== 1'b0) begin
    `uvm_error(get_full_name(),
               $sformatf({"An R accept started between edges ended after %0d R handshakes, with ",
                          "RVALID %0b afterwards: it should take exactly one."},
                         cfg.m_probe_vif.m_r_handshakes - handshakes, vif.r_if.rvalid))
  end
endtask : off_edge_r_accept
