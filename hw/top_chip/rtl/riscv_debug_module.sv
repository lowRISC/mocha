// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

`include "prim_assert.sv"

module riscv_debug_module #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter int unsigned XLen = 64
) (
  // Clock, reset and enable.
  input  logic clk_i,
  input  logic rst_ni,
  input  logic debug_en_i,
  output logic debug_en_o,

  // Debug module JTAG signals.
  input  logic tck_i,
  input  logic tms_i,
  input  logic td_i,
  output logic td_o,
  output logic td_en_o,
  input  logic trst_ni,

  // Memory ports.
  output top_pkg::axi_req_t      axi_host_req_o,
  input  top_pkg::axi_resp_t     axi_host_resp_i,
  input  top_pkg::axi_dev_req_t  axi_device_req_i,
  output top_pkg::axi_dev_resp_t axi_device_resp_o,

  // Non-debug module reset.
  output logic ndmreset_req_o,
  input  logic ndmreset_ack_i,

  // Request to processor core.
  output logic debug_req_o
);
  // Masked inputs
  logic                  tms_masked;
  logic                  tdi_masked;
  logic                  trst_masked_n;
  top_pkg::axi_resp_t    axi_host_resp_masked;
  top_pkg::axi_dev_req_t axi_device_req_masked;
  logic                  ndmreset_ack_masked;

  // Intermediate output values.
  logic                   td_out;
  logic                   td_out_en;
  top_pkg::axi_req_t      axi_host_req;
  top_pkg::axi_dev_resp_t axi_device_resp;
  logic                   ndmreset_req;
  logic                   proc_debug_req;

  // JTAG to DMI signals
  logic          debug_req_valid;
  logic          debug_req_ready;
  dm::dmi_req_t  debug_req;
  logic          debug_resp_valid;
  logic          debug_resp_ready;
  dm::dmi_resp_t debug_resp;

  // Debug module host interface signals
  logic              dm_host_req;
  logic [XLen-1:0]   dm_host_addr;
  logic              dm_host_we;
  logic [XLen-1:0]   dm_host_wdata;
  logic [XLen/8-1:0] dm_host_be;
  logic              dm_host_gnt;
  logic              dm_host_r_valid;
  logic [XLen-1:0]   dm_host_r_rdata;

  // Debug module device interface signals
  logic              dm_device_req;
  logic              dm_device_we;
  logic [XLen-1:0]   dm_device_addr;
  logic [XLen/8-1:0] dm_device_be;
  logic [XLen-1:0]   dm_device_wdata;
  logic              dm_device_rvalid;
  logic [XLen-1:0]   dm_device_rdata;

  // Capture debug enable input on first clock cycle only.
  logic debug_en_q;
  logic debug_en_capture_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      debug_en_capture_q <= 1'b1;
      debug_en_q <= 1'b0;
    end else begin
      debug_en_capture_q <= 1'b0;
      debug_en_q <= debug_en_capture_q ? debug_en_i : debug_en_q;
    end
  end

  assign debug_en_o = debug_en_q;

  // Hold all inputs when debug module is disabled
  assign tms_masked = debug_en_q ? tms_i : 1'b0;
  assign tdi_masked = debug_en_q ? td_i : 1'b0;
  assign trst_masked_n = debug_en_q ? trst_ni : 1'b0;
  assign axi_host_resp_masked = debug_en_q ? axi_host_resp_i : '0;
  assign axi_device_req_masked = debug_en_q ? axi_device_req_i : '0;
  assign ndmreset_ack_masked = debug_en_q ? ndmreset_ack_i : 1'b0;

  // JTAG to DMI bridge
  dmi_jtag  #(
    .IdcodeValue(jtag_id_pkg::RV_DM_JTAG_IDCODE)
  ) u_dmi_jtag (
    .clk_i            (clk_i),
    .rst_ni           (rst_ni),
    .testmode_i       (1'b0),
    .test_rst_ni      (1'b1),
    .dmi_rst_no       ( ),
    .dmi_req_valid_o  (debug_req_valid),
    .dmi_req_ready_i  (debug_req_ready),
    .dmi_req_o        (debug_req),
    .dmi_resp_valid_i (debug_resp_valid),
    .dmi_resp_ready_o (debug_resp_ready),
    .dmi_resp_i       (debug_resp),
    .tck_i            (tck_i),
    .tms_i            (tms_masked),
    .trst_ni          (trst_masked_n),
    .td_i             (tdi_masked),
    .td_o             (td_out),
    .tdo_oe_o         (td_out_en)
  );

  // Debug module AXI host adapter
  axi_adapter #(
    .CVA6Cfg    ( CVA6Cfg             ),
    .DATA_WIDTH ( XLen                ),
    .axi_req_t  ( top_pkg::axi_req_t  ),
    .axi_rsp_t  ( top_pkg::axi_resp_t )
  ) u_dm_host_axi_adapter (
    .clk_i                 (clk_i),
    .rst_ni                (rst_ni),
    .req_i                 (dm_host_req),
    .type_i                (ariane_pkg::SINGLE_REQ),
    .amo_i                 (ariane_pkg::AMO_NONE),
    .gnt_o                 (dm_host_gnt),
    .addr_i                (dm_host_addr),
    .we_i                  (dm_host_we),
    .wdata_i               (dm_host_wdata),
    .be_i                  (dm_host_be),
    .size_i                (2'b11), // XLEN=64
    .id_i                  ('0),
    .valid_o               (dm_host_r_valid),
    .rdata_o               (dm_host_r_rdata),
    .id_o                  ( ),
    .critical_word_o       ( ),
    .critical_word_valid_o ( ),
    .axi_req_o             (axi_host_req),
    .axi_resp_i            (axi_host_resp_masked)
  );

  // Debug module AXI device adapter
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_dev_req_t  ),
    .axi_resp_t ( top_pkg::axi_dev_resp_t ),
    .AddrWidth  ( top_pkg::AxiAddrWidth   ),
    .DataWidth  ( top_pkg::AxiDataWidth   ),
    .IdWidth    ( top_pkg::AxiDevIdWidth  ),
    .NumBanks   ( 1                       )
  ) u_dm_device_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (axi_device_req_masked),
    .axi_resp_o (axi_device_resp),

    // Memory interface.
    .mem_req_o    (dm_device_req),
    .mem_gnt_i    (1'b1),
    .mem_addr_o   (dm_device_addr),
    .mem_wdata_o  (dm_device_wdata),
    .mem_strb_o   (dm_device_be),
    .mem_atop_o   ( ), // Atomics not used
    .mem_we_o     (dm_device_we),
    .mem_rvalid_i (dm_device_rvalid),
    .mem_rdata_i  (dm_device_rdata)
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dm_device_rvalid <= 1'b0;
    end else begin
      dm_device_rvalid <= dm_device_req; // Generate rvalid strobes even for writes
    end
  end

  // Instantiate Debug Module
  dm_top #(
    .NrHarts         ( 1                       ),
    .BusWidth        ( XLen                    ),
    .DmBaseAddress   ( top_pkg::DebugMemBase32 ),
    .SelectableHarts ( 1'b1                    ),
    .ReadByteEnable  ( 1                       )
  ) u_dm_top (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .next_dm_addr_i       ('0), // Single debug module; end of the DMI chain.
    .testmode_i           (1'b0),
    .ndmreset_o           (ndmreset_req),
    .ndmreset_ack_i       (ndmreset_ack_masked),
    .dmactive_o           ( ), // active debug session
    .debug_req_o          (proc_debug_req),
    .unavailable_i        (1'b0),
    .hartinfo_i           ({ariane_pkg::DebugHartInfo}),
    .slave_req_i          (dm_device_req),
    .slave_we_i           (dm_device_we),
    .slave_addr_i         (dm_device_addr),
    .slave_be_i           (dm_device_be),
    .slave_wdata_i        (dm_device_wdata),
    .slave_rdata_o        (dm_device_rdata),
    .master_req_o         (dm_host_req),
    .master_add_o         (dm_host_addr),
    .master_we_o          (dm_host_we),
    .master_wdata_o       (dm_host_wdata),
    .master_be_o          (dm_host_be),
    .master_gnt_i         (dm_host_gnt),
    .master_r_valid_i     (dm_host_r_valid),
    .master_r_err_i       ('0),
    .master_r_other_err_i ('0),
    .master_r_rdata_i     (dm_host_r_rdata),
    .dmi_rst_ni           (rst_ni),
    .dmi_req_valid_i      (debug_req_valid),
    .dmi_req_ready_o      (debug_req_ready),
    .dmi_req_i            (debug_req),
    .dmi_resp_valid_o     (debug_resp_valid),
    .dmi_resp_ready_i     (debug_resp_ready),
    .dmi_resp_o           (debug_resp)
  );

  ///////////////////////////////
  // Blanking out the outputs. //
  ///////////////////////////////

  prim_blanker u_td_o_blanker (
    .in_i  (td_out),
    .en_i  (debug_en_q),
    .out_o (td_o)
  );

  prim_blanker u_tdo_en_blanker (
    .in_i  (td_out_en),
    .en_i  (debug_en_q),
    .out_o (td_en_o)
  );

  assign axi_host_req_o = '{
    aw:       axi_host_req.aw,
    aw_valid: debug_en_q ? axi_host_req.aw_valid : 1'b0,
    w:        axi_host_req.w,
    w_valid:  debug_en_q ? axi_host_req.w_valid  : 1'b0,
    b_ready:  debug_en_q ? axi_host_req.b_ready  : 1'b0,
    ar:       axi_host_req.ar,
    ar_valid: debug_en_q ? axi_host_req.ar_valid : 1'b0,
    r_ready:  debug_en_q ? axi_host_req.r_ready  : 1'b0
  };

  assign axi_device_resp_o = '{
    aw_ready: debug_en_q ? axi_device_resp.aw_ready : 1'b0,
    ar_ready: debug_en_q ? axi_device_resp.ar_ready : 1'b0,
    w_ready:  debug_en_q ? axi_device_resp.w_ready  : 1'b0,
    b_valid:  debug_en_q ? axi_device_resp.b_valid  : 1'b0,
    b:        axi_device_resp.b,
    r_valid:  debug_en_q ? axi_device_resp.r_valid  : 1'b0,
    r:        axi_device_resp.r
  };

  prim_blanker u_ndmreset_blanker (
    .in_i  (ndmreset_req),
    .en_i  (debug_en_q),
    .out_o (ndmreset_req_o)
  );

  prim_blanker u_debug_req_blanker (
    .in_i  (proc_debug_req),
    .en_i  (debug_en_q),
    .out_o (debug_req_o)
  );

  ////////////////
  // Assertions //
  ////////////////

`ifdef INC_ASSERT

  // Assertions to know whether the input masking is working.
  `ASSERT(TdoInternalDisable_A, !debug_en_q |-> ($stable(td_out) && td_out == 1'b0))
  `ASSERT(TdenoInternalDisable_A, !debug_en_q |-> ($stable(td_out_en) && td_out_en == 1'b0))
  `ASSERT(AxiHostInternalDisable_A, !debug_en_q |-> (
    $stable(axi_host_req) &&
    axi_host_req.aw_valid == 1'b0 &&
    axi_host_req.w_valid == 1'b0 &&
    axi_host_req.ar_valid == 1'b0 &&
    axi_host_req.b_ready == 1'b0 &&
    axi_host_req.r_ready == 1'b0
  ))
  `ASSERT(AxiDeviceInternalDisable_A, !debug_en_q |-> (
    $stable(axi_device_resp.aw_ready) &&
    $stable(axi_device_resp.w_ready) &&
    $stable(axi_device_resp.ar_ready) &&
    $stable(axi_device_resp.b_valid) &&
    $stable(axi_device_resp.r_valid) &&
    axi_device_resp.aw_ready == 1'b0 &&
    axi_device_resp.w_ready == 1'b0 &&
    axi_device_resp.ar_ready == 1'b0 &&
    axi_device_resp.b_valid == 1'b0 &&
    axi_device_resp.r_valid == 1'b0
  ))
  `ASSERT(NdmResetInternalDisable_A, !debug_en_q |-> (
    $stable(ndmreset_req) && ndmreset_req == 1'b0
  ))
  `ASSERT(DebugReqInternalDisable_A, !debug_en_q |-> (
    $stable(proc_debug_req) && proc_debug_req == 1'b0
  ))

  // Assertions to know whether the output blanking is working.
  `ASSERT(TdoDisable_A, !debug_en_q |-> ($stable(td_o) && td_o == 1'b0))
  `ASSERT(TdenoDisable_A, !debug_en_q |-> ($stable(td_en_o) && td_en_o == 1'b0))
  `ASSERT(AxiHostDisable_A, !debug_en_q |-> (
    $stable(axi_host_req_o) &&
    axi_host_req_o.aw_valid == 1'b0 &&
    axi_host_req_o.w_valid == 1'b0 &&
    axi_host_req_o.ar_valid == 1'b0 &&
    axi_host_req_o.b_ready == 1'b0 &&
    axi_host_req_o.r_ready == 1'b0
  ))
  `ASSERT(AxiDeviceDisable_A, !debug_en_q |-> (
    $stable(axi_device_resp_o.aw_ready) &&
    $stable(axi_device_resp_o.w_ready) &&
    $stable(axi_device_resp_o.ar_ready) &&
    $stable(axi_device_resp_o.b_valid) &&
    $stable(axi_device_resp_o.r_valid) &&
    axi_device_resp_o.aw_ready == 1'b0 &&
    axi_device_resp_o.w_ready == 1'b0 &&
    axi_device_resp_o.ar_ready == 1'b0 &&
    axi_device_resp_o.b_valid == 1'b0 &&
    axi_device_resp_o.r_valid == 1'b0
  ))
  `ASSERT(NdmResetDisable_A, !debug_en_q |-> (
    $stable(ndmreset_req_o) && ndmreset_req_o == 1'b0
  ))
  `ASSERT(DebugReqDisable_A, !debug_en_q |-> (
    $stable(debug_req_o) && debug_req_o == 1'b0
  ))
`endif
endmodule
