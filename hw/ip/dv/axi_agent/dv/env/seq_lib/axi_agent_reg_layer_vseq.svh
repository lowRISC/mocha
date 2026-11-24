// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Repeated parallel register writes and readbacks exercise same-ID concurrency. Word-aligned 32-bit
// registers use upper lanes on wider buses, and individual byte-field writes strobe one lane.
// AXI4-Lite requests use a fixed AxPROT. With +axi_reg_predictor, disable auto prediction and feed
// the mirror from the manager monitor, filtering failed accesses. Registers in the SLVERR region
// must report UVM_NOT_OK and leave the mirror unchanged. With AXI4 exclusive support, failed
// exclusive writes answered OKAY must also leave the mirror unchanged. A two-byte access at an odd
// address checks the layer's transfer size, and the predictor test checks the adapter on unaligned
// transfers. On AXI4, register reads run without ARUSER while AWUSER keeps its width.

class axi_agent_reg_layer_vseq extends axi_agent_base_vseq;
  `uvm_object_utils(axi_agent_reg_layer_vseq)

  int unsigned m_num_regs      = 8;
  int unsigned m_num_byte_regs = 4;
  int unsigned m_num_err_regs  = 2;
  int unsigned m_num_rounds    = 8;

  // Standard SV/UVM methods
  extern function new(string name = "");
  extern task body();

  // Class specific methods

  // Write registers in parallel with random values, writing one byte field at a time or whole
  // byte-field registers when requested
  extern protected task write_all(axi_agent_reg_block reg_block, bit whole_byte_regs);

  // Read every register at once and check it against the mirror
  extern protected task check_all(axi_agent_reg_block reg_block);

  // Check failed register reads and writes leave the mirror unchanged
  extern protected task check_err_regs(axi_agent_reg_block reg_block);

  // Check an exclusive write without a prior read fails and leaves the mirror unchanged, then a
  // matching read/write succeeds (H.c A7.2.3, A7.2.5). Requires subordinate exclusive support.
  extern protected task check_excl_writes(axi_agent_reg_block reg_block);

  // Send one access straight to the register layer and return its status and read data
  extern protected task send_reg_op(uvm_access_e kind, addr_t addr, int unsigned n_bits,
                                    uvm_reg_byte_en_t byte_en, uvm_reg_data_t wdata,
                                    output uvm_status_e status, output uvm_reg_data_t rdata);

  // Write two bytes at an odd address past the registers and read them back through the layer. Both
  // bytes must use their addressed lanes (H.c A3.4.1, A3.4.4).
  extern protected task check_unaligned_access();

  // Check that the adapter reports only the bytes that an unaligned single transfer carries
  extern protected function void check_adapter_lanes();
endclass : axi_agent_reg_layer_vseq


function axi_agent_reg_layer_vseq::new(string name = "");
  super.new(name);
endfunction : new

task axi_agent_reg_layer_vseq::write_all(axi_agent_reg_block reg_block, bit whole_byte_regs);
  fork
    begin : isolation_fork
      foreach (reg_block.regs[i]) begin
        automatic axi_agent_reg rg = reg_block.regs[i];

        fork
          begin
            uvm_status_e status;

            rg.write(status, $urandom(), .parent(this));
            if (status != UVM_IS_OK) begin
              `uvm_error(get_full_name(), $sformatf("Writing %0s failed.", rg.get_name()))
            end
          end
        join_none
      end
      foreach (reg_block.byte_regs[i]) begin
        automatic axi_agent_byte_reg rg = reg_block.byte_regs[i];
        automatic int unsigned       k  = $urandom_range(0, 3);

        fork
          begin
            uvm_status_e status;

            if (whole_byte_regs) begin
              rg.write(status, $urandom(), .parent(this));
            end else begin
              rg.bytes[k].write(status, $urandom_range(0, 255), .parent(this));
            end
            if (status != UVM_IS_OK) begin
              `uvm_error(get_full_name(), $sformatf("Writing %0s failed.", rg.get_name()))
            end
          end
        join_none
      end
      wait fork;
    end
  join
endtask : write_all

task axi_agent_reg_layer_vseq::check_all(axi_agent_reg_block reg_block);
  uvm_reg regs[$];

  foreach (reg_block.regs[i]) begin
    regs.push_back(reg_block.regs[i]);
  end
  foreach (reg_block.byte_regs[i]) begin
    regs.push_back(reg_block.byte_regs[i]);
  end
  fork
    begin : isolation_fork
      foreach (regs[i]) begin
        automatic uvm_reg rg = regs[i];

        fork
          begin
            uvm_status_e status;

            rg.mirror(status, UVM_CHECK, .parent(this));
            if (status != UVM_IS_OK) begin
              `uvm_error(get_full_name(), $sformatf("Reading %0s failed.", rg.get_name()))
            end
          end
        join_none
      end
      wait fork;
    end
  join
endtask : check_all

task axi_agent_reg_layer_vseq::check_err_regs(axi_agent_reg_block reg_block);
  foreach (reg_block.err_regs[i]) begin
    axi_agent_reg  rg = reg_block.err_regs[i];
    uvm_reg_data_t mirror = rg.get_mirrored_value();
    uvm_reg_data_t value;
    uvm_status_e   status;

    rg.write(status, ~mirror & 32'hffff_ffff, .parent(this));
    if (status != UVM_NOT_OK) begin
      `uvm_error(get_full_name(), $sformatf("Writing %0s, in the error region, returned %0s.",
                                            rg.get_name(), status.name()))
    end
    rg.read(status, value, .parent(this));
    if (status != UVM_NOT_OK) begin
      `uvm_error(get_full_name(), $sformatf("Reading %0s, in the error region, returned %0s.",
                                            rg.get_name(), status.name()))
    end
    if (rg.get_mirrored_value() != mirror) begin
      `uvm_error(get_full_name(),
                 $sformatf("The mirror of %0s went from 0x%0h to 0x%0h after failed accesses.",
                           rg.get_name(), mirror, rg.get_mirrored_value()))
    end
  end
endtask : check_err_regs

task axi_agent_reg_layer_vseq::check_excl_writes(axi_agent_reg_block reg_block);
  axi_agent_reg      rg = reg_block.regs[0];
  uvm_reg_data_t     mirror = rg.get_mirrored_value();
  addr_t             addr = rg.get_address();
  axi_agent_rand_req req = axi_agent_rand_req::type_id::create("req");
  uvm_status_e       status;

  // Full strobes make successful exclusive writes cover the whole register
  m_partial_strb_pct = 0;
  req.set_bus(cfg);
  req.m_allow_lock = 1'b1;
  `DV_CHECK_RANDOMIZE_WITH_FATAL(req,
                                 m_addr  == local::addr;
                                 m_len   == 0;
                                 m_size  == 2;
                                 m_burst == BurstIncr;
                                 m_lock  == 1'b1;)

  // The exclusive write has no prior read, so it fails and the predictor must not see it
  send_expect(req, 1'b1, RespOkay, "exclusive write with no exclusive read");
  @(posedge cfg.clk_rst_vif.clk);
  if (rg.get_mirrored_value() != mirror) begin
    `uvm_error(get_full_name(),
               $sformatf("A failed exclusive write moved the mirror of %0s from 0x%0h to 0x%0h.",
                         rg.get_name(), mirror, rg.get_mirrored_value()))
  end
  rg.mirror(status, UVM_CHECK, .parent(this));
  if (status != UVM_IS_OK) begin
    `uvm_error(get_full_name(), $sformatf("Reading %0s failed.", rg.get_name()))
  end

  // Matching exclusive read/write succeeds, and the predictor must update
  send_expect(req, 1'b0, RespExOkay, "exclusive read of a register");
  send_expect(req, 1'b1, RespExOkay, "matching exclusive write to a register");
  @(posedge cfg.clk_rst_vif.clk);
  rg.mirror(status, UVM_CHECK, .parent(this));
  if (status != UVM_IS_OK) begin
    `uvm_error(get_full_name(), $sformatf("Reading %0s failed.", rg.get_name()))
  end
endtask : check_excl_writes

task axi_agent_reg_layer_vseq::send_reg_op(uvm_access_e kind, addr_t addr, int unsigned n_bits,
                                           uvm_reg_byte_en_t byte_en, uvm_reg_data_t wdata,
                                           output uvm_status_e status,
                                           output uvm_reg_data_t rdata);
  axi_reg_op_item   op = axi_reg_op_item::type_id::create("op");
  uvm_sequence_item rsp;
  axi_reg_op_item   rsp_op;

  op.m_rw.kind    = kind;
  op.m_rw.addr    = addr;
  op.m_rw.data    = wdata;
  op.m_rw.n_bits  = n_bits;
  op.m_rw.byte_en = byte_en;
  op.m_rw.status  = UVM_IS_OK;
  op.set_sequencer(p_sequencer.m_mgr_agent.get_register_layering_sequencer());
  start_item(op);
  finish_item(op);
  get_base_response(rsp, op.get_transaction_id());
  if (!$cast(rsp_op, rsp)) begin
    `uvm_fatal(get_full_name(), "The register layer answered with an item of another type.")
  end
  status = rsp_op.m_rw.status;
  rdata  = rsp_op.m_rw.data;
endtask : send_reg_op

task axi_agent_reg_layer_vseq::check_unaligned_access();
  addr_t         addr = cfg.m_link.m_addr_lo + 4 * (m_num_regs + m_num_byte_regs) + 1;
  uvm_status_e   status;
  uvm_reg_data_t rdata;

  send_reg_op(UVM_WRITE, addr, 16, 'b11, 16'haa55, status, rdata);
  if (status != UVM_IS_OK) begin
    `uvm_error(get_full_name(), $sformatf("A 16-bit write at 0x%0h returned %0s.", addr,
                                          status.name()))
  end
  send_reg_op(UVM_READ, addr, 16, 'b11, 0, status, rdata);
  if (status != UVM_IS_OK || rdata[15:0] != 16'haa55) begin
    `uvm_error(get_full_name(), $sformatf("A 16-bit read at 0x%0h returned %0s and 0x%0h.", addr,
                                          status.name(), rdata))
  end
endtask : check_unaligned_access

function void axi_agent_reg_layer_vseq::check_adapter_lanes();
  axi_reg_adapter    adapter = p_sequencer.m_mgr_agent.get_reg_adapter();
  axi_mon_read_item  rd = axi_mon_read_item::type_id::create("rd");
  axi_mon_write_item wr = axi_mon_write_item::type_id::create("wr");
  uvm_reg_bus_op     rw;

  // A two-byte transfer at address 1 carries only byte 1, though the other lanes hold data
  rd.m_araddr = 1;
  rd.m_arlen  = 0;
  rd.m_arsize = 1;
  rd.m_rdata.push_back(32'h3322_1100);
  rd.m_rresp.push_back(RespOkay);
  adapter.bus2reg(rd, rw);
  if (rw.n_bits != 8 || rw.byte_en != 'b1 || rw.data != 'h11 || rw.status != UVM_IS_OK) begin
    `uvm_error(get_full_name(),
               $sformatf("An unaligned read became %0d bits 0x%0h (bytes %0b), %0s.", rw.n_bits,
                         rw.data, rw.byte_en, rw.status.name()))
  end
  wr.m_awaddr = 1;
  wr.m_awlen  = 0;
  wr.m_awsize = 1;
  wr.m_wdata.push_back(32'h3322_1100);
  wr.m_wstrb.push_back('b0010);
  wr.m_bresp = RespOkay;
  adapter.bus2reg(wr, rw);
  if (rw.n_bits != 8 || rw.byte_en != 'b1 || rw.data != 'h11 || rw.status != UVM_IS_OK) begin
    `uvm_error(get_full_name(),
               $sformatf("An unaligned write became %0d bits 0x%0h (bytes %0b), %0s.", rw.n_bits,
                         rw.data, rw.byte_en, rw.status.name()))
  end
endfunction : check_adapter_lanes

task axi_agent_reg_layer_vseq::body();
  axi_mgr_agent       agent = p_sequencer.m_mgr_agent;
  axi_vif_t           vif = agent.get_vif();
  int unsigned        aruser_width = vif.ar_if.user_req_width;
  axi_agent_reg_block reg_block = axi_agent_reg_block::type_id::create("reg_block");
  bit                 use_predictor = (p_sequencer.m_reg_predictor != null);
  int unsigned        num_err_regs = use_predictor ? m_num_err_regs : 0;
  bit                 has_fixed_prot = cfg.m_is_lite;
  bit [2:0]           fixed_prot = $urandom();
  bit                 check_excl = use_predictor && !cfg.m_is_lite;

  // Register-layer traffic has no axi_transfer_seq records
  cfg.m_mgr_records    = 1'b0;
  cfg.m_has_fixed_prot = has_fixed_prot;
  cfg.m_fixed_prot     = fixed_prot;
  need("same_id_requests", 1);
  need("read_bytes_checked", 4 * (m_num_regs + m_num_byte_regs) * m_num_rounds);
  if (has_fixed_prot) begin
    need("fixed_prot_checked", 2 * (m_num_regs + m_num_byte_regs) * m_num_rounds);
  end
  if (use_predictor) begin
    need("slverr_responses", 2 * num_err_regs);
  end
  if (check_excl) begin
    need("exokay_responses", 2);
    need("exclusive_failures", 1);
  end

  cfg.m_sub_agent_cfg.m_err_addr_valid = (num_err_regs > 0);
  cfg.m_sub_agent_cfg.m_err_addr       = AgentErrPage;
  cfg.m_sub_agent_cfg.m_err_addr_mask  = 64'hfff;
  cfg.m_sub_agent_cfg.m_err_resp       = RespSlverr;

  // Enable exclusive support with prediction on AXI4 (H.c B1.1) and also configure the manager's
  // predictor adapter
  cfg.m_sub_agent_cfg.m_exclusive_support = check_excl;
  agent.get_reg_adapter().set_exclusive_support(check_excl);

  reg_block.build(cfg.m_link.m_addr_lo, m_num_regs, m_num_byte_regs, num_err_regs,
                  AgentErrPage - cfg.m_link.m_addr_lo);
  reg_block.default_map.set_auto_predict(!use_predictor);
  if (use_predictor) begin
    p_sequencer.m_reg_predictor.map = reg_block.default_map;
  end

  // The layer samples bus widths at startup. Reads must fit ARUSER even when it is narrower than
  // AWUSER. Change the width at an edge with no transfer in flight.
  wait_ready();
  if (vif.aw_if.user_req_width > 0) begin
    vif.ar_if.set_user_req_width(0);
  end
  fork
    agent.run_layered_register_vseq(has_fixed_prot, fixed_prot);
  join_none
  wait_ready();
  reg_block.default_map.set_sequencer(agent.get_register_layering_sequencer(),
                                      agent.get_reg_adapter());

  // The layer runs forever, so wait only for register accesses. Initialize every byte by writing
  // byte-field registers whole in the first round.
  for (int unsigned round = 0; round < m_num_rounds; round++) begin
    write_all(reg_block, round == 0);
    check_all(reg_block);
  end
  check_unaligned_access();

  // Restore ARUSER for the transfer sequences below, at an edge with no transfer in flight
  @(posedge cfg.clk_rst_vif.clk);
  vif.ar_if.set_user_req_width(aruser_width);
  if (use_predictor) begin
    int unsigned num_failed = 2 * num_err_regs + check_excl;

    check_adapter_lanes();
    check_err_regs(reg_block);
    if (check_excl) begin
      check_excl_writes(reg_block);
    end
    if (p_sequencer.m_reg_filter.m_num_dropped != num_failed) begin
      `uvm_error(get_full_name(),
                 $sformatf("The filter held back %0d transactions, but %0d failed.",
                           p_sequencer.m_reg_filter.m_num_dropped, num_failed))
    end
  end
endtask : body
