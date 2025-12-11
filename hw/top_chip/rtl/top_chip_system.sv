// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_chip_system #(
  SramInitFile = ""
) (
  // Clock and reset.
  input  logic clk_i,
  input  logic rst_ni,

  // UART receive and transmit.
  input  logic uart_rx_i,
  output logic uart_tx_o
);
  // Local parameters.
  localparam int unsigned SramMemSize   = 128 * 1024; // 128 KiB
  localparam int unsigned TlDataWidth   = top_pkg::TL_DW;
  localparam int unsigned TlIntgWidth   = 7;
  localparam int unsigned AxiAddrOffset = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth = $clog2(SramMemSize) - AxiAddrOffset;
  localparam int unsigned TagAw         = SramAddrWidth - 1;

  // CVA6 configuration
  function automatic config_pkg::cva6_cfg_t build_cva6_config(config_pkg::cva6_user_cfg_t CVA6UserCfg);
    config_pkg::cva6_user_cfg_t cfg = CVA6UserCfg;
    cfg.RVZiCond = bit'(0);
    cfg.CvxifEn = bit'(0);
    cfg.NrNonIdempotentRules = unsigned'(1);
    cfg.NonIdempotentAddrBase = 1024'({64'b0});
    cfg.NonIdempotentLength = 1024'({top_pkg::SRAMBase});
    return build_config_pkg::build_config(cfg);
  endfunction

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_cva6_config(cva6_config_pkg::cva6_cfg);
  cva6_cheri_pkg::cap_pcc_t boot_cap;
  always_comb begin : gen_boot_cap
    boot_cap = cva6_cheri_pkg::PCC_ROOT_CAP;
    boot_cap.addr = top_pkg::SRAMBase + 'h80;
    boot_cap.flags.int_mode = 1'b1;
  end

  // AXI crossbar configuration
  localparam axi_pkg::xbar_cfg_t xbar_cfg = '{
    NoSlvPorts:         int'(top_pkg::AxiXbarHosts),
    NoMstPorts:         int'(top_pkg::AxiXbarDevices),
    MaxMstTrans:        32'd10,
    MaxSlvTrans:        32'd6,
    FallThrough:        1'b0,
    LatencyMode:        axi_pkg::CUT_ALL_AX,
    PipelineStages:     32'd1,
    AxiIdWidthSlvPorts: 32'd5,
    AxiIdUsedSlvPorts:  32'd1,
    UniqueIds:          1'b0,
    AxiAddrWidth:       int'(top_pkg::AxiAddrWidth),
    AxiDataWidth:       int'(top_pkg::AxiDataWidth / 8), // In bytes
    NoAddrRules:        int'(top_pkg::AxiXbarDevices)
  };

  // AXI crossbar address mapping
  axi_pkg::xbar_rule_32_t [xbar_cfg.NoAddrRules-1:0] addr_map;
  assign addr_map = '{
    '{ idx: top_pkg::SRAM,       start_addr: top_pkg::SRAMBase,       end_addr: top_pkg::SRAMBase       + top_pkg::SRAMLength       },
    '{ idx: top_pkg::TlCrossbar, start_addr: top_pkg::TlCrossbarBase, end_addr: top_pkg::TlCrossbarBase + top_pkg::TlCrossbarLength }
  };

  // TileLink signals.
  tlul_pkg::tl_h2d_t tl_axi_xbar_h2d;
  tlul_pkg::tl_d2h_t tl_axi_xbar_d2h;
  tlul_pkg::tl_h2d_t tl_uart_h2d;
  tlul_pkg::tl_d2h_t tl_uart_d2h;

  // 64-bit memory format signals
  logic                                 sram_data_req;
  logic                                 sram_data_we;
  logic [SramAddrWidth-1:0]             sram_data_addr;
  logic [top_pkg::AxiDataWidth-1:0]     sram_data_wmask;
  logic [top_pkg::AxiDataWidth-1:0]     sram_data_wdata;
  logic                                 sram_data_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     sram_data_rdata;
  logic                                 mem64_sram_req;
  logic                                 mem64_sram_gnt;
  logic                                 mem64_sram_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] mem64_sram_be;
  logic [top_pkg::AxiAddrWidth-1:0]     mem64_sram_addr;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_sram_wdata;
  logic                                 mem64_sram_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_sram_rdata;
  logic                                 mem64_uart_req;
  logic                                 mem64_uart_gnt;
  logic                                 mem64_uart_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] mem64_uart_be;
  logic [top_pkg::AxiAddrWidth-1:0]     mem64_uart_addr;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_uart_wdata;
  logic                                 mem64_uart_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_uart_rdata;

  // 32-bit memory format signals
  logic                       mem32_uart_req;
  logic                       mem32_uart_gnt;
  logic                       mem32_uart_we;
  logic [(TlDataWidth/8)-1:0] mem32_uart_be;
  logic [top_pkg::TL_AW-1:0]  mem32_uart_addr;
  logic [TlDataWidth-1:0]     mem32_uart_wdata;
  logic [TlIntgWidth-1:0]     mem32_uart_wdata_intg;
  logic                       mem32_uart_rvalid;
  logic [TlDataWidth-1:0]     mem32_uart_rdata;

  // AXI signals
  top_pkg::axi_req_t  [xbar_cfg.NoSlvPorts-1:0] xbar_host_req;
  top_pkg::axi_resp_t [xbar_cfg.NoSlvPorts-1:0] xbar_host_resp;
  top_pkg::axi_req_t  [xbar_cfg.NoMstPorts-1:0] xbar_device_req;
  top_pkg::axi_resp_t [xbar_cfg.NoMstPorts-1:0] xbar_device_resp;
  // AXI response from SRAM before inserting cap valid bit
  top_pkg::axi_resp_t                           tag_pre_insert_resp;

  // Tag memory signals
  logic             tag_mem_a_req_i;
  logic [TagAw-1:0] tag_mem_a_addr_i;
  logic [0:0]       tag_mem_a_wdata_i;
  logic             tag_mem_b_req_i;
  logic [TagAw-1:0] tag_mem_b_addr_i;
  logic [0:0]       tag_mem_b_rdata_o;

  // Instantiate CVA6-CHERI.
  cva6 #(
    .CVA6Cfg       ( CVA6Cfg                ),
    .axi_ar_chan_t ( top_pkg::axi_ar_chan_t ),
    .axi_aw_chan_t ( top_pkg::axi_aw_chan_t ),
    .axi_w_chan_t  ( top_pkg::axi_w_chan_t  ),
    .b_chan_t      ( top_pkg::axi_b_chan_t  ),
    .r_chan_t      ( top_pkg::axi_r_chan_t  ),
    .noc_req_t     ( top_pkg::axi_req_t     ),
    .noc_resp_t    ( top_pkg::axi_resp_t    )
  ) i_cva6 (
    .clk_i         (clk_i),
    .rst_ni        (rst_ni),
    .boot_addr_i   (boot_cap),
    .hart_id_i     ('0),
    .irq_i         (2'b0),
    .ipi_i         (1'b0),
    .time_irq_i    (1'b0),
    .debug_req_i   (1'b0),
    .rvfi_probes_o ( ),
    .cvxif_req_o   ( ),
    .cvxif_resp_i  ('0),
    .noc_req_o     (xbar_host_req[0]),
    .noc_resp_i    (xbar_host_resp[0])
  );

  // Instantiate our UART block.
  uart u_uart (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),
    .lsio_trigger_o  ( ),

    .cio_rx_i    (uart_rx_i),
    .cio_tx_o    (uart_tx_o),
    .cio_tx_en_o ( ),

    // Inter-module signals.
    .tl_i (tl_uart_h2d),
    .tl_o (tl_uart_d2h),

    // Interrupts.
    .intr_tx_watermark_o  ( ),
    .intr_tx_empty_o      ( ),
    .intr_rx_watermark_o  ( ),
    .intr_tx_done_o       ( ),
    .intr_rx_overflow_o   ( ),
    .intr_rx_frame_err_o  ( ),
    .intr_rx_break_err_o  ( ),
    .intr_rx_timeout_o    ( ),
    .intr_rx_parity_err_o ( )
  );

  // Our RAM
  prim_ram_1p #(
    .Width           ( top_pkg::AxiDataWidth ),
    .DataBitsPerMask ( 8                     ),
    .Depth           ( 2 ** (SramAddrWidth)  ),
    .MemInitFile     ( SramInitFile          )
  ) u_ram (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i   (sram_data_req),
    .write_i (sram_data_we),
    .addr_i  (sram_data_addr),
    .wdata_i (sram_data_wdata),
    .wmask_i (sram_data_wmask),
    .rdata_o (sram_data_rdata),

    .cfg_i     ('0),
    .cfg_rsp_o ( )
  );

  // Single-cycle read response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      sram_data_rvalid <= '0;
    end else begin
      sram_data_rvalid <= sram_data_req; // Generate rvalid strobes even for writes
    end
  end

  // Primary AXI crossbar
  axi_xbar #(
    .Cfg          (xbar_cfg               ),
    .ATOPs        (1'b0                   ),
    .Connectivity ('1                     ),
    .slv_aw_chan_t(top_pkg::axi_aw_chan_t ),
    .mst_aw_chan_t(top_pkg::axi_aw_chan_t ),
    .w_chan_t     (top_pkg::axi_w_chan_t  ),
    .slv_b_chan_t (top_pkg::axi_b_chan_t  ),
    .mst_b_chan_t (top_pkg::axi_b_chan_t  ),
    .slv_ar_chan_t(top_pkg::axi_ar_chan_t ),
    .mst_ar_chan_t(top_pkg::axi_ar_chan_t ),
    .slv_r_chan_t (top_pkg::axi_r_chan_t  ),
    .mst_r_chan_t (top_pkg::axi_r_chan_t  ),
    .slv_req_t    (top_pkg::axi_req_t     ),
    .slv_resp_t   (top_pkg::axi_resp_t    ),
    .mst_req_t    (top_pkg::axi_req_t     ),
    .mst_resp_t   (top_pkg::axi_resp_t    ),
    .rule_t       (axi_pkg::xbar_rule_32_t)
  ) u_axi_xbar (
    .clk_i                (clk_i),
    .rst_ni               (rst_ni),
    .test_i               (1'b0),
    .slv_ports_req_i      (xbar_host_req),
    .slv_ports_resp_o     (xbar_host_resp),
    .mst_ports_req_o      (xbar_device_req),
    .mst_ports_resp_i     (xbar_device_resp),
    .addr_map_i           (addr_map),
    .en_default_mst_port_i('0),
    .default_mst_port_i   ('0)
  );

  // Capability valid bit insertion

  // Assume AW data unchanged until W finished
  assign tag_mem_a_req_i   = xbar_device_resp[0].w_ready && xbar_device_req[0].w_valid && xbar_device_req[0].w.last;
  assign tag_mem_a_addr_i  = (xbar_device_req[0].aw.addr ^ top_pkg::SRAMBase) >> 4;
  assign tag_mem_a_wdata_i = xbar_device_req[0].w.user;
  assign tag_mem_b_req_i   = xbar_device_resp[0].ar_ready && xbar_device_req[0].ar_valid;
  assign tag_mem_b_addr_i  = (xbar_device_req[0].ar.addr ^ top_pkg::SRAMBase) >> 4;

  // Tag memory
  prim_ram_2p #(
    .Width(1),
    .Depth(2 ** (TagAw)),
    .DataBitsPerMask(1)
  ) tag_mem_prim (
    // Write port
    .clk_a_i  (clk_i),
    .a_req_i  (tag_mem_a_req_i),
    .a_write_i(1'b1),
    .a_addr_i (tag_mem_a_addr_i),
    .a_wdata_i(tag_mem_a_wdata_i),
    .a_wmask_i('1),
    .a_rdata_o( ),

    // Read port
    .clk_b_i  (clk_i),
    .b_req_i  (tag_mem_b_req_i),
    .b_write_i(1'b0),
    .b_addr_i (tag_mem_b_addr_i),
    .b_wdata_i('0),
    .b_wmask_i('1),
    .b_rdata_o(tag_mem_b_rdata_o),

    .cfg_i    ('0),
    .cfg_rsp_o()
  );

  // Replace only user field with cap valid bit read from tag memory
  assign xbar_device_resp[0].aw_ready = tag_pre_insert_resp.aw_ready;
  assign xbar_device_resp[0].ar_ready = tag_pre_insert_resp.ar_ready;
  assign xbar_device_resp[0].w_ready  = tag_pre_insert_resp.w_ready;
  assign xbar_device_resp[0].b_valid  = tag_pre_insert_resp.b_valid;
  assign xbar_device_resp[0].b        = tag_pre_insert_resp.b;
  assign xbar_device_resp[0].r_valid  = tag_pre_insert_resp.r_valid;
  assign xbar_device_resp[0].r.id     = tag_pre_insert_resp.r.id;
  assign xbar_device_resp[0].r.data   = tag_pre_insert_resp.r.data;
  assign xbar_device_resp[0].r.resp   = tag_pre_insert_resp.r.resp;
  assign xbar_device_resp[0].r.last   = tag_pre_insert_resp.r.last;
  assign xbar_device_resp[0].r.user   = tag_mem_b_rdata_o;

  // AXI to 64-bit mem for SRAM
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_sram_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (xbar_device_req[0]),
    .axi_resp_o (tag_pre_insert_resp),

    // Memory interface.
    .mem_req_o    (mem64_sram_req),
    .mem_gnt_i    (mem64_sram_gnt),
    .mem_addr_o   (mem64_sram_addr),
    .mem_wdata_o  (mem64_sram_wdata),
    .mem_strb_o   (mem64_sram_be),
    .mem_atop_o   ( ),
    .mem_we_o     (mem64_sram_we),
    .mem_rvalid_i (mem64_sram_rvalid),
    .mem_rdata_i  (mem64_sram_rdata)
  );

  // 64-bit SRAM signal assignments
  assign sram_data_req   = mem64_sram_req;
  assign mem64_sram_gnt  = 1'b1;
  // Remove base offset and convert byte address to 64-bit word address
  assign sram_data_addr  = (mem64_sram_addr ^ top_pkg::SRAMBase) >> 3;
  assign sram_data_we    = mem64_sram_we;
  assign sram_data_wdata = mem64_sram_wdata;
  always_comb begin
    for (int i=0; i < (top_pkg::AxiDataWidth / 8); ++i) begin
      sram_data_wmask[i*8 +: 8] = {8{mem64_sram_be[i]}};
    end
  end
  assign mem64_sram_rvalid = sram_data_rvalid;
  assign mem64_sram_rdata  = sram_data_rdata;

  // AXI to 64-bit mem for UART
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_uart_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (xbar_device_req[1]),
    .axi_resp_o (xbar_device_resp[1]),

    // Memory interface.
    .mem_req_o    (mem64_uart_req),
    .mem_gnt_i    (mem64_uart_gnt),
    .mem_addr_o   (mem64_uart_addr),
    .mem_wdata_o  (mem64_uart_wdata),
    .mem_strb_o   (mem64_uart_be),
    .mem_atop_o   ( ),
    .mem_we_o     (mem64_uart_we),
    .mem_rvalid_i (mem64_uart_rvalid),
    .mem_rdata_i  (mem64_uart_rdata)
  );

  // 64-bit mem to 32-bit mem for UART
  mem_downsizer u_uart_mem_downsizer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    // 64-bit memory request in
    .mem64_req_i   (mem64_uart_req),
    .mem64_gnt_o   (mem64_uart_gnt),
    .mem64_we_i    (mem64_uart_we),
    .mem64_be_i    (mem64_uart_be),
    .mem64_addr_i  (mem64_uart_addr),
    .mem64_wdata_i (mem64_uart_wdata),
    .mem64_rvalid_o(mem64_uart_rvalid),
    .mem64_rdata_o (mem64_uart_rdata),

    // 32-bit memory request out
    .mem32_req_o   (mem32_uart_req),
    .mem32_gnt_i   (mem32_uart_gnt),
    .mem32_we_o    (mem32_uart_we),
    .mem32_be_o    (mem32_uart_be),
    .mem32_addr_o  (mem32_uart_addr),
    .mem32_wdata_o (mem32_uart_wdata),
    .mem32_rvalid_i(mem32_uart_rvalid),
    .mem32_rdata_i (mem32_uart_rdata)
  );

  // 32-bit mem to TLUL for UART
  tlul_adapter_host #(
    .EnableDataIntgGen      ( 1 ),
    .EnableRspDataIntgCheck ( 1 )
  ) u_uart_tlul_host_adapter (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    .req_i        (mem32_uart_req),
    .gnt_o        (mem32_uart_gnt),
    .addr_i       (mem32_uart_addr),
    .we_i         (mem32_uart_we),
    .wdata_i      (mem32_uart_wdata),
    .wdata_intg_i (mem32_uart_wdata_intg),
    .be_i         (mem32_uart_be),
    .instr_type_i (prim_mubi_pkg::MuBi4False),
    .user_rsvd_i  ('0),

    .valid_o      (mem32_uart_rvalid),
    .rdata_o      (mem32_uart_rdata),
    .rdata_intg_o ( ),
    .err_o        ( ),
    .intg_err_o   ( ),

    .tl_o         (tl_axi_xbar_h2d),
    .tl_i         (tl_axi_xbar_d2h)
  );

  // TileLink peripheral crossbar
  xbar_peri u_tl_xbar (
    // Clock and reset.
    .clk_i,
    .rst_ni,

    // Host interfaces.
    .tl_axi_xbar_i(tl_axi_xbar_h2d),
    .tl_axi_xbar_o(tl_axi_xbar_d2h),

    // Device interfaces.
    .tl_uart_o(tl_uart_h2d),
    .tl_uart_i(tl_uart_d2h),

    .scanmode_i (prim_mubi_pkg::MuBi4False)
  );
endmodule
