// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Scoreboard -- subscribes to the agent's monitor (m_transaction_port) and checks the DUT
  // against the reference model: every access must return OKAY with the modelled data/tag.
  class axi_sram_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(axi_sram_scoreboard)

    uvm_analysis_imp #(axi_mon_item, axi_sram_scoreboard) tx_imp;
    axi_sram_ref_model m_model;

    int unsigned m_writes, m_reads;
    int unsigned m_data_errs, m_tag_errs, m_resp_errs;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      tx_imp = new("tx_imp", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_model = axi_sram_ref_model::type_id::create("m_model");
    endfunction

    // Analysis callback (m_transaction_port only ever emits fully merged transactions).
    function void write(axi_mon_item tr);
      axi_mon_write_item wr;
      axi_mon_read_item  rd;
      if      ($cast(wr, tr)) check_write(wr);
      else if ($cast(rd, tr)) check_read(rd);
    endfunction

    protected function void check_write(axi_mon_write_item tr);
      m_writes++;
      if (tr.m_bresp != axi_write_response_item::BRespOkay) begin
        `uvm_error(get_full_name(), $sformatf(
                   "write @0x%0h (id 0x%0h): BRESP=%0d (expected OKAY)",
                   tr.m_awaddr, tr.m_bid, tr.m_bresp))
        m_resp_errs++;
      end
      m_model.predict_write(tr);
    endfunction

    protected function void check_read(axi_mon_read_item tr);
      bit [63:0] exp_data[$];
      bit        exp_user[$];
      m_reads++;
      m_model.predict_read(tr, exp_data, exp_user);
      foreach (tr.m_rdata[i]) begin
        // Same beat-address rule the prediction used, so a message always names the location
        // that was compared.
        bit [63:0] baddr = m_model.beat_addr(tr.m_araddr, tr.m_arsize, tr.m_arburst, i);
        if (tr.m_rresp[i] != axi_read_data_item::RRespOkay) begin
          `uvm_error(get_full_name(), $sformatf(
                     "read @0x%0h beat %0d (id 0x%0h): RRESP=%0d (expected OKAY)",
                     baddr, i, tr.m_rid, tr.m_rresp[i]))
          m_resp_errs++;
        end
        if (tr.m_rdata[i][63:0] != exp_data[i]) begin
          `uvm_error(get_full_name(), $sformatf(
                     "read DATA @0x%0h beat %0d (id 0x%0h): got 0x%016h, model 0x%016h",
                     baddr, i, tr.m_rid, tr.m_rdata[i][63:0], exp_data[i]))
          m_data_errs++;
        end
        if (tr.m_ruser[i][0] != exp_user[i]) begin
          `uvm_error(get_full_name(), $sformatf(
                     "read TAG  @0x%0h beat %0d (id 0x%0h): got %0b, model %0b",
                     baddr, i, tr.m_rid, tr.m_ruser[i][0], exp_user[i]))
          m_tag_errs++;
        end
      end
    endfunction

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info(get_full_name(), $sformatf({"scoreboard: %0d writes, %0d reads checked; ",
                "data_errs=%0d tag_errs=%0d resp_errs=%0d"},
                m_writes, m_reads,
                m_data_errs, m_tag_errs, m_resp_errs), UVM_LOW)
    endfunction
  endclass
