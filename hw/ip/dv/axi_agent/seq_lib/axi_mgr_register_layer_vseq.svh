// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// This is a register layering virtual sequence. It consumes axi_reg_op_item objects from a
// sequencer and uses them to trigger multiple bus sequences for the different AXI channels (AW, W,
// B, AR and R).
//
// It is designed to be used with axi_reg_adapter with provides_responses=1, so calls put() on
// m_layered_sequencer to provide responses to the operations.

class axi_mgr_register_layer_vseq extends uvm_sequence;
  `uvm_object_utils(axi_mgr_register_layer_vseq)

  // A sequencer used as a source of register transactions can be run, and the five AXI channels.
  // These can be provided by calling set_sequencers, which must be done before starting this
  // sequence.
  local uvm_sequencer #(axi_reg_op_item) m_layered_sequencer;
  local write_request_sequencer_t        m_aw_sequencer;
  local write_data_sequencer_t           m_w_sequencer;
  local write_response_sequencer_t       m_b_sequencer;
  local read_request_sequencer_t         m_ar_sequencer;
  local read_data_sequencer_t            m_r_sequencer;

  // Read and write response routers
  local axi_response_router        m_read_response_router;
  local axi_response_router        m_write_response_router;

  // Constrain requests to data, ID and USER widths; call set_bus_properties before starting
  local int unsigned m_data_width      = AxiMaxDataWidth;
  local int unsigned m_id_w_width      = AxiMaxIdWidth;
  local int unsigned m_id_r_width      = AxiMaxIdWidth;
  local int unsigned m_awuser_width    = AxiMaxReqUserWidth;
  local int unsigned m_aruser_width    = AxiMaxReqUserWidth;
  local int unsigned m_user_data_width = AxiMaxDataUserWidth;

  extern function new(string name="");
  extern task body();

  extern function void set_sequencers(uvm_sequencer#(axi_reg_op_item) layered_sequencer,
                                      write_request_sequencer_t       aw_sequencer,
                                      write_data_sequencer_t          w_sequencer,
                                      write_response_sequencer_t      b_sequencer,
                                      read_request_sequencer_t        ar_sequencer,
                                      read_data_sequencer_t           r_sequencer);

  extern function void set_response_routers(axi_response_router read_response_router,
                                            axi_response_router write_response_router);

  extern function void set_bus_properties(int unsigned data_width,
                                          int unsigned id_w_width,
                                          int unsigned id_r_width,
                                          int unsigned awuser_width,
                                          int unsigned aruser_width,
                                          int unsigned user_data_width);

  // Send the request item through a layered sequence, passing any information back by modifying the
  // item argument (specifically, by modifying its m_rw field).
  extern local task send_op_item(axi_reg_op_item item);
endclass

function axi_mgr_register_layer_vseq::new(string name="");
  super.new(name);
endfunction

task axi_mgr_register_layer_vseq::body();
  if (m_layered_sequencer == null ||
      m_aw_sequencer == null ||
      m_w_sequencer == null ||
      m_b_sequencer == null ||
      m_ar_sequencer == null ||
      m_r_sequencer == null ||
      m_read_response_router == null ||
      m_write_response_router == null) begin
    `uvm_fatal(get_full_name(),
               "Cannot run sequence because at least one sequencer or router is null.")
  end

  fork : isolation_fork begin
    forever begin
      axi_reg_op_item item;
      m_layered_sequencer.get(item);

      // Run the item in the background. The send_op_item task completes when the generated virtual
      // sequence runs to completion, modifying the item in its item argument to represent the
      // response.
      //
      // At that point, we call m_layered_sequencer.put(item). The item will have originally come
      // from an axi_reg_adapter and the response will now be passed back to that adapter's bus2reg,
      // which will be able to update a uvm_reg_bus_op in a uvm_reg_map, completing the operation
      // handshake.
      fork begin
        send_op_item(item);
        m_layered_sequencer.put(item);
      end join_none
    end
  end join
endtask

function void
  axi_mgr_register_layer_vseq::set_sequencers(uvm_sequencer#(axi_reg_op_item) layered_sequencer,
                                              write_request_sequencer_t       aw_sequencer,
                                              write_data_sequencer_t          w_sequencer,
                                              write_response_sequencer_t      b_sequencer,
                                              read_request_sequencer_t        ar_sequencer,
                                              read_data_sequencer_t           r_sequencer);
  if (layered_sequencer == null) `uvm_fatal(get_full_name(), "No layered sequencer")
  if (aw_sequencer == null) `uvm_fatal(get_full_name(), "No aw sequencer")
  if (w_sequencer == null)  `uvm_fatal(get_full_name(), "No w sequencer")
  if (b_sequencer == null)  `uvm_fatal(get_full_name(), "No b sequencer")
  if (ar_sequencer == null) `uvm_fatal(get_full_name(), "No ar sequencer")
  if (r_sequencer == null)  `uvm_fatal(get_full_name(), "No r sequencer")

  m_layered_sequencer = layered_sequencer;
  m_aw_sequencer      = aw_sequencer;
  m_w_sequencer       = w_sequencer;
  m_b_sequencer       = b_sequencer;
  m_ar_sequencer      = ar_sequencer;
  m_r_sequencer       = r_sequencer;
endfunction

function void
  axi_mgr_register_layer_vseq::set_response_routers(axi_response_router read_response_router,
                                                    axi_response_router write_response_router);
  if (read_response_router == null)  `uvm_fatal(get_full_name(), "No read response router.")
  if (write_response_router == null) `uvm_fatal(get_full_name(), "No write response router.")

  m_read_response_router  = read_response_router;
  m_write_response_router = write_response_router;
endfunction

function void axi_mgr_register_layer_vseq::set_bus_properties(int unsigned data_width,
                                                              int unsigned id_w_width,
                                                              int unsigned id_r_width,
                                                              int unsigned awuser_width,
                                                              int unsigned aruser_width,
                                                              int unsigned user_data_width);
  m_data_width      = data_width;
  m_id_w_width      = id_w_width;
  m_id_r_width      = id_r_width;
  m_awuser_width    = awuser_width;
  m_aruser_width    = aruser_width;
  m_user_data_width = user_data_width;
endfunction: set_bus_properties

task axi_mgr_register_layer_vseq::send_op_item(axi_reg_op_item item);
  // This task handles the bulk of the work that would normally be done by a uvm_reg_adapter's
  // reg2bus and bus2reg functions.

  // n_bits describes bits accessed from the address; field byte_en may select higher bytes within
  // the register. Bursts are unsupported, so cover both ranges and round up to ARSIZE/AWSIZE.
  int unsigned num_bytes = (item.m_rw.n_bits + 7) / 8;
  int unsigned axsize;

  // This is the maximum strb value possible, given axsize. If byte_en is not maximal, the strb
  // value to actually use might not have all of the bits set.
  bit [AxiMaxStrbWidth-1:0] strb_from_size;

  // The register's lowest byte uses lane addr % bus_bytes (AMBA AXI H.c A3.4.1, A3.4.4)
  int unsigned bus_bytes = m_data_width / 8;
  int unsigned lane = item.m_rw.addr % bus_bytes;

  // The strb value to send on W, or the byte mask to use with rdata in an R response. This takes
  // size, byte_en and the byte lane into account.
  bit [AxiMaxStrbWidth-1:0] byte_mask;

  bit [AxiMaxDataWidth-1:0] wdata = AxiMaxDataWidth'(item.m_rw.data) << (8 * lane);

  for (int unsigned i = 0; i < $bits(item.m_rw.byte_en); i++) begin
    if (item.m_rw.byte_en[i] && i + 1 > num_bytes) begin
      num_bytes = i + 1;
    end
  end
  // A transfer carries the bytes from its address to the end of its AxSIZE-aligned container (AMBA
  // AXI H.c A3.4.1). Use the smallest container that holds every byte of the access.
  axsize = $clog2(num_bytes);
  while ((1 << axsize) < bus_bytes && lane % (1 << axsize) + num_bytes > (1 << axsize)) begin
    axsize++;
  end
  strb_from_size = (AxiMaxStrbWidth'(1) << (1 << axsize)) - 1;
  byte_mask      = (strb_from_size & item.m_rw.byte_en) << lane;

  if ((1 << axsize) > bus_bytes || lane % (1 << axsize) + num_bytes > (1 << axsize)) begin
    `uvm_error(get_full_name(),
               $sformatf("A %0d-byte register access at 0x%0h does not fit one %0d-byte transfer.",
                         num_bytes, item.m_rw.addr, bus_bytes))
    item.m_rw.status = UVM_NOT_OK;
    return;
  end

  case (item.m_rw.kind)
    UVM_READ: begin
      // Single read
      axi_mgr_read_burst_vseq read_vseq = axi_mgr_read_burst_vseq::type_id::create("read_vseq");
      bit          ar_complete, r_complete;
      bit [AxiMaxDataWidth-1:0] bit_mask;

      read_vseq.set_sequencers(m_ar_sequencer, m_r_sequencer);
      read_vseq.set_read_response_router(m_read_response_router);

      if (!read_vseq.randomize() with {
            m_ar_req.m_len == 0;
            m_ar_req.m_burst == BurstIncr;
            m_ar_req.m_addr == local::item.m_rw.addr;
            m_ar_req.m_size == local::axsize;

            (m_ar_req.m_id >> local::m_id_r_width) == 0;
            (m_ar_req.m_user >> local::m_aruser_width) == 0;
            m_ar_req.m_lock == 1'b0;
          }) begin
        `uvm_fatal(get_full_name(), "Failed to randomise read_vseq.")
      end

      // Run read_vseq to completion, which will set a rsp field (the sequence is designed to do so
      // on every path).
      read_vseq.start(null);

      // Convert byte_mask into a mask that can be used with rdata
      for (int unsigned i = 0; i < 128; i++) begin
        if (byte_mask[i]) bit_mask |= 1024'hff << 8 * i;
      end

      ar_complete = (read_vseq.rsp.m_ar_status != null &&
                     read_vseq.rsp.m_ar_status.m_sending_complete);
      r_complete = (read_vseq.rsp.m_read_data.size() > 0);

      item.m_rw.status = (ar_complete && r_complete &&
                          read_vseq.rsp.m_read_data[0].m_resp inside
                            {axi_read_data_item::RRespOkay,
                             axi_read_data_item::RRespExOkay}) ?
                         UVM_IS_OK :
                         UVM_NOT_OK;
      item.m_rw.data   = r_complete ?
                         ((read_vseq.rsp.m_read_data[0].m_data & bit_mask) >> (8 * lane)) : 0;
    end

    UVM_WRITE: begin
      // Single write
      axi_mgr_write_burst_vseq write_vseq = axi_mgr_write_burst_vseq::type_id::create("write_vseq");
      axi_write_data_item      w_beat = axi_write_data_item::type_id::create("w_beat");
      bit aw_complete, w_complete, b_complete;

      write_vseq.set_sequencers(m_aw_sequencer, m_w_sequencer, m_b_sequencer);
      write_vseq.set_write_response_router(m_write_response_router);

      if (!w_beat.randomize() with {
            m_data == local::wdata;
            m_strb == local::byte_mask;
            (m_user >> local::m_user_data_width) == 0;
          }) begin
        `uvm_fatal(get_full_name(), "Failed to randomise w_beat.")
      end
      write_vseq.m_data_items.push_back(w_beat);

      if (!write_vseq.randomize() with {
            m_aw_req.m_burst == BurstIncr;
            m_aw_req.m_addr == local::item.m_rw.addr;
            m_aw_req.m_size == local::axsize;

            (m_aw_req.m_id >> local::m_id_w_width) == 0;
            (m_aw_req.m_user >> local::m_awuser_width) == 0;
            m_aw_req.m_lock == 1'b0;
          }) begin
        `uvm_fatal(get_full_name(), "Failed to randomise write_vseq.")
      end

      // Run write_vseq to completion, which will set a rsp field (the sequence is designed to do so
      // on every path).
      write_vseq.start(null);

      aw_complete = (write_vseq.rsp.m_aw_status != null &&
                     write_vseq.rsp.m_aw_status.m_sending_complete);
      w_complete = (write_vseq.rsp.m_w_status != null &&
                    write_vseq.rsp.m_w_status.m_sending_complete);
      b_complete = (write_vseq.rsp.m_write_response != null);

      item.m_rw.status = (aw_complete && w_complete && b_complete &&
                          write_vseq.rsp.m_write_response.m_resp inside
                            {axi_write_response_item::BRespOkay,
                             axi_write_response_item::BRespExOkay}) ?
                         UVM_IS_OK :
                         UVM_NOT_OK;
    end

    default: begin
      // Something else (a burst read or write). Not yet supported.
      `uvm_error(get_full_name(),
                 $sformatf("Cannot send this uvm_reg_op. kind is %0s, which is not supported.",
                           item.m_rw.kind.name()))
      item.m_rw.status = UVM_NOT_OK;
      return;
    end
  endcase
endtask
