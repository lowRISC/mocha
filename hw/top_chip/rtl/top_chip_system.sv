// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0


module top_chip_system #(
  SramInitFile = ""
) (
  // Clock and reset.
  input  logic clk_i,
  input  logic rst_ni,

  // GPIO inputs and outputs with output enable
  input  logic [31:0] gpio_i,
  output logic [31:0] gpio_o,
  output logic [31:0] gpio_en_o,

  // UART receive and transmit.
  input  logic uart_rx_i,
  output logic uart_tx_o,

  // SPI device receive and transmit.
  input  logic       spi_device_sck_i,
  input  logic       spi_device_csb_i,
  output logic [3:0] spi_device_sd_o,
  output logic [3:0] spi_device_sd_en_o,
  input  logic [3:0] spi_device_sd_i,
  input  logic       spi_device_tpm_csb_i,

  // JTAG signals.
  input  logic dm_jtag_tck,
  input  logic dm_jtag_tms,
  input  logic dm_jtag_tdi,
  output logic dm_jtag_tdo,
  input  logic dm_jtag_trst_n
);
  // Local parameters.
  localparam int unsigned SramMemSize   = 128 * 1024; // 128 KiB
  localparam int unsigned TlDataWidth   = top_pkg::TL_DW;
  localparam int unsigned AxiAddrOffset = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth = $clog2(SramMemSize) - AxiAddrOffset;
  localparam int unsigned GpioIrqs      = 32;
  localparam int unsigned UartIrqs      = 9;
  localparam int unsigned SPIDeviceIrqs = 8;

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
    AxiIdWidthSlvPorts: 32'd4,
    AxiIdUsedSlvPorts:  32'd1,
    UniqueIds:          1'b0,
    AxiAddrWidth:       int'(top_pkg::AxiAddrWidth),
    AxiDataWidth:       int'(top_pkg::AxiDataWidth / 8), // In bytes
    NoAddrRules:        int'(top_pkg::AxiXbarDevices)
  };

  // AXI crossbar address mapping
  axi_pkg::xbar_rule_64_t [xbar_cfg.NoAddrRules-1:0] addr_map;
  assign addr_map = '{
    '{ idx: top_pkg::SRAM,       start_addr: top_pkg::SRAMBase,       end_addr: top_pkg::SRAMBase       + top_pkg::SRAMLength       },
    '{ idx: top_pkg::TlCrossbar, start_addr: top_pkg::TlCrossbarBase, end_addr: top_pkg::TlCrossbarBase + top_pkg::TlCrossbarLength },
    '{ idx: top_pkg::DM_DEV,     start_addr: top_pkg::DebugBase,      end_addr: top_pkg::DebugBase      + top_pkg::DebugLength      }
  };

  // TileLink signals.
  tlul_pkg::tl_h2d_t tl_axi_xbar_h2d;
  tlul_pkg::tl_d2h_t tl_axi_xbar_d2h;
  tlul_pkg::tl_h2d_t tl_gpio_h2d;
  tlul_pkg::tl_d2h_t tl_gpio_d2h;
  tlul_pkg::tl_h2d_t tl_uart_h2d;
  tlul_pkg::tl_d2h_t tl_uart_d2h;
  tlul_pkg::tl_h2d_t tl_timer_h2d;
  tlul_pkg::tl_d2h_t tl_timer_d2h;
  tlul_pkg::tl_h2d_t tl_plic_h2d;
  tlul_pkg::tl_d2h_t tl_plic_d2h;
  tlul_pkg::tl_h2d_t tl_spi_device_h2d;
  tlul_pkg::tl_d2h_t tl_spi_device_d2h;

  // 64-bit memory format signals
  logic                                 mem64_tl_xbar_req;
  logic                                 mem64_tl_xbar_gnt;
  logic                                 mem64_tl_xbar_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] mem64_tl_xbar_be;
  logic [top_pkg::AxiAddrWidth-1:0]     mem64_tl_xbar_addr;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_tl_xbar_wdata;
  logic                                 mem64_tl_xbar_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_tl_xbar_rdata;

  // 32-bit memory format signals
  logic                       mem32_tl_xbar_req;
  logic                       mem32_tl_xbar_gnt;
  logic                       mem32_tl_xbar_we;
  logic [(TlDataWidth/8)-1:0] mem32_tl_xbar_be;
  logic [top_pkg::TL_AW-1:0]  mem32_tl_xbar_addr;
  logic [TlDataWidth-1:0]     mem32_tl_xbar_wdata;
  logic                       mem32_tl_xbar_rvalid;
  logic [TlDataWidth-1:0]     mem32_tl_xbar_rdata;

  // AXI signals
  top_pkg::axi_req_t  [xbar_cfg.NoSlvPorts-1:0] xbar_host_req;
  top_pkg::axi_resp_t [xbar_cfg.NoSlvPorts-1:0] xbar_host_resp;
  top_pkg::axi_req_t  [xbar_cfg.NoMstPorts-1:0] xbar_device_req;
  top_pkg::axi_resp_t [xbar_cfg.NoMstPorts-1:0] xbar_device_resp;

  // IP block raised interrupts
  logic [GpioIrqs-1:0]      gpio_interrupts;
  logic [UartIrqs-1:0]      uart_interrupts;
  logic [SPIDeviceIrqs-1:0] spi_device_interrupts;

  // Interrupt lines to PLIC
  // Each IP block has a single interrupt line to the PLIC and software shall consult the intr_state
  // register within the block itself to identify the interrupt source(s).
  logic gpio_irq;
  logic uart_irq;
  logic spi_device_irq;

  // JTAG to DMI signals
  logic         debug_req_valid;
  logic         debug_req_ready;
  dm::dmi_req_t debug_req;

  logic          debug_resp_valid;
  logic          debug_resp_ready;
  dm::dmi_resp_t debug_resp;

  always_comb begin
    // Single interrupt line per IP block.
    gpio_irq = |gpio_interrupts;
    uart_irq = |uart_interrupts;
    spi_device_irq = |spi_device_interrupts;
  end

  // Interrupt vector
  logic [31:0] intr_vector;

  assign intr_vector[31 :10] = '0;      // Reserved for future use.
  assign intr_vector[ 9    ] = gpio_irq;
  assign intr_vector[ 8    ] = uart_irq;
  assign intr_vector[ 7    ] = spi_device_irq;
  assign intr_vector[ 6 : 0] = '0;      // Reserved for future use.

  // Interrupts to the CVA6
  logic       intr_timer;
  logic [1:0] intr;
  logic       debug_req_irq;

  // Signals to intercept AXI traffic from CVA6 for DV puprose
  top_pkg::axi_req_t  cva6_to_sim_req;
  top_pkg::axi_resp_t sim_to_cva6_resp;

  // Signals to connect AXI traffic to and from Debug Module master
  top_pkg::axi_req_t  dm_axi_m_req;
  top_pkg::axi_resp_t dm_axi_m_resp;

  // Debug module master interface signals
  logic                      dm_master_req;
  logic [CVA6Cfg.XLEN-1:0]   dm_master_add;
  logic                      dm_master_we;
  logic [CVA6Cfg.XLEN-1:0]   dm_master_wdata;
  logic [CVA6Cfg.XLEN/8-1:0] dm_master_be;
  logic                      dm_master_gnt;
  logic                      dm_master_r_valid;
  logic [CVA6Cfg.XLEN-1:0]   dm_master_r_rdata;

  // Debug module slave interface signals
  logic                      dm_slave_req;
  logic                      dm_slave_we;
  logic [CVA6Cfg.XLEN-1:0]   dm_slave_addr;
  logic [CVA6Cfg.XLEN/8-1:0] dm_slave_be;
  logic [CVA6Cfg.XLEN-1:0]   dm_slave_wdata;
  logic [CVA6Cfg.XLEN-1:0]   dm_slave_rdata;
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( top_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( top_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( top_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( top_pkg::AxiUserWidth )
  ) axi_debug_master();

  // Debug-controlled reset
  logic ndmreset;
  logic ndmreset_n;
  assign ndmreset_n = ~ndmreset;

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
    .rst_ni        (ndmreset_n),
    .boot_addr_i   (boot_cap),
    .hart_id_i     ('0),
    .irq_i         (intr),
    .ipi_i         (1'b0),
    .time_irq_i    (intr_timer),
    .debug_req_i   (debug_req_irq),
    .rvfi_probes_o ( ),
    .cvxif_req_o   ( ),
    .cvxif_resp_i  ('0),
    .noc_req_o     (cva6_to_sim_req),
    .noc_resp_i    (sim_to_cva6_resp)
  );

  // JTAG to DMI bridge
  dmi_jtag i_dmi_jtag (
    .clk_i           ( clk_i           ),
    .rst_ni          ( rst_ni          ),
    .testmode_i      ( 1'b0            ),
    .test_rst_ni     ( 1'b1            ),
    .dmi_rst_no      (                 ), // keep open
    .dmi_req_valid_o ( debug_req_valid ),
    .dmi_req_ready_i ( debug_req_ready ),
    .dmi_req_o       ( debug_req       ),
    .dmi_resp_valid_i( debug_resp_valid),
    .dmi_resp_ready_o( debug_resp_ready),
    .dmi_resp_i      ( debug_resp      ),
    .tck_i           ( dm_jtag_tck     ),
    .tms_i           ( dm_jtag_tms     ),
    .trst_ni         ( dm_jtag_trst_n  ),
    .td_i            ( dm_jtag_tdi     ),
    .td_o            ( dm_jtag_tdo     ),
    .tdo_oe_o        (                 )
  );

  // Debug Module AXI Master Adapter
  axi_adapter #(
      .CVA6Cfg               ( CVA6Cfg                   ),
      .DATA_WIDTH            ( CVA6Cfg.XLEN              ),
      .axi_req_t             ( top_pkg::axi_req_t        ),
      .axi_rsp_t             ( top_pkg::axi_resp_t       )
  ) i_dm_axi_master (
      .clk_i                 ( clk_i                     ),
      .rst_ni                ( rst_ni                    ),
      .req_i                 ( dm_master_req             ),
      .type_i                ( ariane_pkg::SINGLE_REQ    ),
      .amo_i                 ( ariane_pkg::AMO_NONE      ),
      .gnt_o                 ( dm_master_gnt             ),
      .addr_i                ( dm_master_add             ),
      .we_i                  ( dm_master_we              ),
      .wdata_i               ( dm_master_wdata           ),
      .be_i                  ( dm_master_be              ),
      .size_i                ( 2'b11                     ), // XLEN=64
      .id_i                  ( '0                        ),
      .valid_o               ( dm_master_r_valid         ),
      .rdata_o               ( dm_master_r_rdata         ),
      .id_o                  (                           ),
      .critical_word_o       (                           ),
      .critical_word_valid_o (                           ),
      .axi_req_o             ( dm_axi_m_req              ),
      .axi_resp_i            ( dm_axi_m_resp             )
  );

  assign xbar_host_req[top_pkg::DM_HOST] = dm_axi_m_req; // TODO: Make top_pkg::DM exist
  assign dm_axi_m_resp                   = xbar_host_resp[top_pkg::DM_HOST];

  // Debug Module AXI Slave Adapter
  //`AXI_ASSIGN_FROM_REQ(axi_debug_master, xbar_device_req[top_pkg::DM_DEV])
  //`AXI_ASSIGN_TO_RESP(xbar_device_resp[top_pkg::DM_DEV], axi_debug_master)
  //axi2mem #(
  //    .AXI_ID_WIDTH   ( top_pkg::AxiIdWidth   ),
  //    .AXI_ADDR_WIDTH ( CVA6Cfg.XLEN          ),
  //    .AXI_DATA_WIDTH ( CVA6Cfg.XLEN          ),
  //    .AXI_USER_WIDTH ( top_pkg::AxiUserWidth )
  //) i_dm_axi2mem (
  //    .clk_i      ( clk_i                     ),
  //    .rst_ni     ( rst_ni                    ),
  //    .slave      ( axi_debug_master          ),
  //    .req_o      ( dm_slave_req              ),
  //    .we_o       ( dm_slave_we               ),
  //    .addr_o     ( dm_slave_addr             ),
  //    .be_o       ( dm_slave_be               ),
  //    .data_o     ( dm_slave_wdata            ),
  //    .data_i     ( dm_slave_rdata            ),
  //    .user_o     ( '0                        ),
  //    .user_i     ( '0                        )
  //);
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) i_dm_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (xbar_device_req[top_pkg::DM_DEV]),
    .axi_resp_o (xbar_device_resp[top_pkg::DM_DEV]),

    // Memory interface.
    .mem_req_o    (dm_slave_req),
    .mem_gnt_i    (1'b1), // XXX TODO this signal wasn't present in originally used axi2mem module
    .mem_addr_o   (dm_slave_addr),
    .mem_wdata_o  (dm_slave_wdata),
    .mem_strb_o   (dm_slave_be),
    .mem_atop_o   ( ), // XXX TODO this signal wasn't present in originally used axi2mem module
    .mem_we_o     (dm_slave_we),
    .mem_rvalid_i (1'b1), // XXX TODO this signal wasn't present in originally used axi2mem module
    .mem_rdata_i  (dm_slave_rdata)
  );

  // Instantiate Debug Module
  dm_top #(
    .NrHarts             ( 1                 ),
    .BusWidth            ( CVA6Cfg.XLEN      ),
    .SelectableHarts     ( 1'b1              )
  ) i_dm_top (
      .clk_i             ( clk_i             ),
      .rst_ni            ( rst_ni            ),
      .testmode_i        ( 1'b0              ),
      .ndmreset_o        ( ndmreset          ),
      .dmactive_o        (                   ), // active debug session
      .debug_req_o       ( debug_req_irq     ),
      .unavailable_i     ( 1'b0              ),
      .hartinfo_i        ( {ariane_pkg::DebugHartInfo} ),
      .slave_req_i       ( dm_slave_req      ),
      .slave_we_i        ( dm_slave_we       ),
      .slave_addr_i      ( dm_slave_addr     ),
      .slave_be_i        ( dm_slave_be       ),
      .slave_wdata_i     ( dm_slave_wdata    ),
      .slave_rdata_o     ( dm_slave_rdata    ),
      .master_req_o      ( dm_master_req     ),
      .master_add_o      ( dm_master_add     ),
      .master_we_o       ( dm_master_we      ),
      .master_wdata_o    ( dm_master_wdata   ),
      .master_be_o       ( dm_master_be      ),
      .master_gnt_i      ( dm_master_gnt     ),
      .master_r_valid_i  ( dm_master_r_valid ),
      .master_r_err_i    ( '0                ),
      .master_r_other_err_i ( '0             ),
      .master_r_rdata_i  ( dm_master_r_rdata ),
      .dmi_rst_ni        ( rst_ni            ),
      .dmi_req_valid_i   ( debug_req_valid   ),
      .dmi_req_ready_o   ( debug_req_ready   ),
      .dmi_req_i         ( debug_req         ),
      .dmi_resp_valid_o  ( debug_resp_valid  ),
      .dmi_resp_ready_i  ( debug_resp_ready  ),
      .dmi_resp_o        ( debug_resp        )
  );

  // Interception point for connecting simulation SRAM by disconnecting the AXI output. The
  // disconnection is done only if `SYNTHESIS is NOT defined AND `INST_SIM_SRAM is defined.
  // This define is used only for Verilator as it does not support forces.
`ifdef INST_SIM_SRAM
`ifdef SYNTHESIS
  // Induce a compilation error by instantiating a non-existent module.
  illegal_preprocessor_branch_taken u_illegal_preprocessor_branch_taken();
`endif
`else
  assign xbar_host_req[top_pkg::CVA6] = cva6_to_sim_req;
  assign sim_to_cva6_resp             = xbar_host_resp[top_pkg::CVA6];
`endif

  // AXI SRAM
  axi_sram #(
    .AddrWidth   ( SramAddrWidth         ),
    .MemInitFile ( SramInitFile          )
  ) u_axi_sram (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    // Capability AXI interface
    .axi_req_i  (xbar_device_req[top_pkg::SRAM]),
    .axi_resp_o (xbar_device_resp[top_pkg::SRAM])
  );

  // Primary AXI crossbar
  axi_xbar #(
    .Cfg          (xbar_cfg               ),
    .ATOPs        (1'b0                   ),
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
    .rule_t       (axi_pkg::xbar_rule_64_t)
  ) u_axi_xbar (
    .clk_i                (clk_i),
    .rst_ni               (ndmreset_n),
    .test_i               (1'b0),
    .slv_ports_req_i      (xbar_host_req),
    .slv_ports_resp_o     (xbar_host_resp),
    .mst_ports_req_o      (xbar_device_req),
    .mst_ports_resp_i     (xbar_device_resp),
    .addr_map_i           (addr_map),
    .en_default_mst_port_i('0),
    .default_mst_port_i   ('0)
  );

  // AXI to 64-bit mem for TLUL crossbar
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_tl_xbar_axi_to_mem (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (xbar_device_req[top_pkg::TlCrossbar]),
    .axi_resp_o (xbar_device_resp[top_pkg::TlCrossbar]),

    // Memory interface.
    .mem_req_o    (mem64_tl_xbar_req),
    .mem_gnt_i    (mem64_tl_xbar_gnt),
    .mem_addr_o   (mem64_tl_xbar_addr),
    .mem_wdata_o  (mem64_tl_xbar_wdata),
    .mem_strb_o   (mem64_tl_xbar_be),
    .mem_atop_o   ( ),
    .mem_we_o     (mem64_tl_xbar_we),
    .mem_rvalid_i (mem64_tl_xbar_rvalid),
    .mem_rdata_i  (mem64_tl_xbar_rdata)
  );

  // 64-bit mem to 32-bit mem for TLUL crossbar
  mem_downsizer u_tl_xbar_mem_downsizer (
    .clk_i(clk_i),
    .rst_ni(ndmreset_n),

    // 64-bit memory request in
    .mem64_req_i   (mem64_tl_xbar_req),
    .mem64_gnt_o   (mem64_tl_xbar_gnt),
    .mem64_we_i    (mem64_tl_xbar_we),
    .mem64_be_i    (mem64_tl_xbar_be),
    .mem64_addr_i  (mem64_tl_xbar_addr),
    .mem64_wdata_i (mem64_tl_xbar_wdata),
    .mem64_rvalid_o(mem64_tl_xbar_rvalid),
    .mem64_rdata_o (mem64_tl_xbar_rdata),

    // 32-bit memory request out
    .mem32_req_o   (mem32_tl_xbar_req),
    .mem32_gnt_i   (mem32_tl_xbar_gnt),
    .mem32_we_o    (mem32_tl_xbar_we),
    .mem32_be_o    (mem32_tl_xbar_be),
    .mem32_addr_o  (mem32_tl_xbar_addr),
    .mem32_wdata_o (mem32_tl_xbar_wdata),
    .mem32_rvalid_i(mem32_tl_xbar_rvalid),
    .mem32_rdata_i (mem32_tl_xbar_rdata)
  );

  // 32-bit mem to TLUL for TLUL crossbar
  tlul_adapter_host #(
    .EnableDataIntgGen      ( 1 ),
    .EnableRspDataIntgCheck ( 1 )
  ) u_tl_xbar_tlul_host_adapter (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    .req_i        (mem32_tl_xbar_req),
    .gnt_o        (mem32_tl_xbar_gnt),
    .addr_i       (mem32_tl_xbar_addr),
    .we_i         (mem32_tl_xbar_we),
    .wdata_i      (mem32_tl_xbar_wdata),
    .wdata_intg_i ('0),
    .be_i         (mem32_tl_xbar_be),
    .instr_type_i (prim_mubi_pkg::MuBi4False),
    .user_rsvd_i  ('0),

    .valid_o      (mem32_tl_xbar_rvalid),
    .rdata_o      (mem32_tl_xbar_rdata),
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
    .rst_ni          (ndmreset_n),

    // Host interfaces.
    .tl_axi_xbar_i   (tl_axi_xbar_h2d),
    .tl_axi_xbar_o   (tl_axi_xbar_d2h),

    // Device interfaces.
    .tl_gpio_o       (tl_gpio_h2d),
    .tl_gpio_i       (tl_gpio_d2h),
    .tl_uart_o       (tl_uart_h2d),
    .tl_uart_i       (tl_uart_d2h),
    .tl_spi_device_o (tl_spi_device_h2d),
    .tl_spi_device_i (tl_spi_device_d2h),
    .tl_timer_o      (tl_timer_h2d),
    .tl_timer_i      (tl_timer_d2h),
    .tl_plic_o       (tl_plic_h2d),
    .tl_plic_i       (tl_plic_d2h),

    .scanmode_i (prim_mubi_pkg::MuBi4False)
  );

  // Instantiate GPIO block from IP template
  gpio #(
    .GpioAsyncOn(1), // inputs may be directly connected to external I/O or other SoC clock domains
    .GpioAsHwStrapsEn(0) // straps not our problem when we are only a SoC subsystem
  ) u_gpio (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),

    // Unused strap ports
    .strap_en_i       ('0),
    .sampled_straps_o ( ),

    // GPIOs
    .cio_gpio_i    (gpio_i),
    .cio_gpio_o    (gpio_o),
    .cio_gpio_en_o (gpio_en_o),

    // Signals to xbar
    .tl_i (tl_gpio_h2d),
    .tl_o (tl_gpio_d2h),

    // Interrupts
    .intr_gpio_o (gpio_interrupts)
  );

  // Instantiate our UART block.
  uart u_uart (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

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
    // Note: the indexes here match the bits in the `intr_` registers,
    // but we also keep the port ordering the same as the module.
    .intr_tx_watermark_o  (uart_interrupts[0]),
    .intr_tx_empty_o      (uart_interrupts[8]),
    .intr_rx_watermark_o  (uart_interrupts[1]),
    .intr_tx_done_o       (uart_interrupts[2]),
    .intr_rx_overflow_o   (uart_interrupts[3]),
    .intr_rx_frame_err_o  (uart_interrupts[4]),
    .intr_rx_break_err_o  (uart_interrupts[5]),
    .intr_rx_timeout_o    (uart_interrupts[6]),
    .intr_rx_parity_err_o (uart_interrupts[7])
  );

  // Instantiate timer
  rv_timer u_timer (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),

    // Signals to xbar
    .tl_i (tl_timer_h2d),
    .tl_o (tl_timer_d2h),

    // Interrupt
    .intr_timer_expired_hart0_timer0_o (intr_timer)
  );

  // Instantiate PLIC
  rv_plic u_rv_plic (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    // Signals to xbar
    .tl_i (tl_plic_h2d),
    .tl_o (tl_plic_d2h),

    // Interrupt sources
    .intr_src_i(intr_vector),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    // Interrupt to targets
    .irq_o    (intr),
    .irq_id_o ( ),

    .msip_o ( )
  );

  // Instantiate SPI device
  spi_device u_spi_device (
    .clk_i  (clk_i),
    .rst_ni (ndmreset_n),

    // Signals to xbar
    .tl_i (tl_spi_device_h2d),
    .tl_o (tl_spi_device_d2h),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),

    // SPI interface
    .cio_sck_i     (spi_device_sck_i),
    .cio_csb_i     (spi_device_csb_i),
    .cio_sd_o      (spi_device_sd_o),
    .cio_sd_en_o   (spi_device_sd_en_o),
    .cio_sd_i      (spi_device_sd_i),
    .cio_tpm_csb_i (spi_device_tpm_csb_i),

    .passthrough_o ( ),
    .passthrough_i (spi_device_pkg::PASSTHROUGH_RSP_DEFAULT),

    // Interrupts
    .intr_upload_cmdfifo_not_empty_o (spi_device_interrupts[0]),
    .intr_upload_payload_not_empty_o (spi_device_interrupts[1]),
    .intr_upload_payload_overflow_o  (spi_device_interrupts[2]),
    .intr_readbuf_watermark_o        (spi_device_interrupts[3]),
    .intr_readbuf_flip_o             (spi_device_interrupts[4]),
    .intr_tpm_header_not_empty_o     (spi_device_interrupts[5]),
    .intr_tpm_rdfifo_cmd_end_o       (spi_device_interrupts[6]),
    .intr_tpm_rdfifo_drop_o          (spi_device_interrupts[7]),

    .ram_cfg_sys2spi_i     (prim_ram_2p_pkg::RAM_2P_CFG_DEFAULT),
    .ram_cfg_rsp_sys2spi_o ( ),
    .ram_cfg_spi2sys_i     (prim_ram_2p_pkg::RAM_2P_CFG_DEFAULT),
    .ram_cfg_rsp_spi2sys_o ( ),

    .sck_monitor_o ( ),

    .mbist_en_i  ('0),
    .scan_clk_i  ('0),
    .scan_rst_ni ('1),
    .scanmode_i  (prim_mubi_pkg::MuBi4False)
  );
endmodule
