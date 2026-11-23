// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  // Step: send one access on the subordinate op names and wait for its response. A DUT that stops
  // responding fails the test at once.
  class tagctrl_access_seq extends tagctrl_base_seq;
    `uvm_object_utils(tagctrl_access_seq)

    // Set before starting; holds the read data once the access completes
    tagctrl_op op;

    function new(string name = "tagctrl_access_seq");
      super.new(name);
    endfunction

    task body();
      axi_txn_sequencer_t seqr = (op.port == PortCfg) ? p_sequencer.cfg_seqr : p_sequencer.tag_seqr;
      axi_transfer_seq    seq  = axi_transfer_seq::type_id::create("seq");

      `uvm_info(get_name(), op.convert2string(), UVM_HIGH)
      seq.set_bus_properties(seqr.m_vif);
      if (!seq.randomize() with { m_write       == local::op.write;
                                  m_req.m_id    == local::op.id;
                                  m_req.m_addr  == local::op.addr;
                                  m_req.m_len   == local::op.len;
                                  m_req.m_size  == local::op.size;
                                  m_req.m_burst == local::op.burst;
                                  m_req.m_lock  == 1'b0;
                                  m_req.m_user  == '0; }) begin
        `uvm_fatal(get_full_name(), {"Cannot randomize ", op.convert2string()})
      end
      // Keep only the bytes each beat carries
      if (op.write) begin
        foreach (op.wdata[n]) begin
          bit [63:0]   beat_addr;
          int unsigned lower, upper, nbytes;
          axi_beat_lanes(op.addr, op.size, op.len, op.burst, BusBytes, n, beat_addr, lower,
                         upper);
          nbytes = upper - lower + 1;
          seq.m_beat_wdata.push_back(nbytes == 8 ? op.wdata[n] :
                                                   op.wdata[n] & ((64'h1 << (8 * nbytes)) - 1));
          seq.m_beat_wstrb.push_back(op.wstrb[n] & ((9'h1 << nbytes) - 1));
          seq.m_beat_wuser.push_back(op.wuser[n]);
        end
      end
      fork begin
        fork
          seq.start(seqr);
          begin
            p_sequencer.cfg.clk_rst_vif.wait_clks(MaxOpClks);
            `uvm_fatal(get_full_name(), {"DUT stopped responding to ", op.convert2string()})
          end
        join_any
        disable fork;
      end join
      if (!seq.has_full_transaction()) begin
        `uvm_fatal(get_full_name(), {"No complete response to ", op.convert2string()})
      end
      op.rdata.delete();
      if (!op.write) foreach (seq.m_responses[n]) op.rdata.push_back(seq.m_responses[n].m_rdata);
    endtask
  endclass
