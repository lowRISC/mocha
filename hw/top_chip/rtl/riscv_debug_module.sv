// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module riscv_debug_module #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
  parameter int unsigned XLen = 64
) (
  // Clock and reset.
  input  logic clk_i,
  input  logic rst_ni,

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
    .tms_i            (tms_i),
    .trst_ni          (trst_ni),
    .td_i             (td_i),
    .td_o             (td_o),
    .tdo_oe_o         (td_en_o)
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
    .axi_req_o             (axi_host_req_o),
    .axi_resp_i            (axi_host_resp_i)
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
    .axi_req_i  (axi_device_req_i),
    .axi_resp_o (axi_device_resp_o),

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
    .ndmreset_o           (ndmreset_req_o),
    .ndmreset_ack_i       (ndmreset_ack_i),
    .dmactive_o           ( ), // active debug session
    .debug_req_o          (debug_req_o),
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
endmodule
