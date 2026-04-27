// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Include macros for tag controller
`include "register_interface/assign.svh"
`include "register_interface/typedef.svh"

module top_chip_system #(
  parameter int unsigned SPIHostNumCS = 1,
  parameter              SramInitFile = "",
  parameter              RomInitFile  = ""
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

  // I^2C controller/target bidirectional interface.
  input  logic i2c_scl_i,
  output logic i2c_scl_o,
  output logic i2c_scl_en_o,
  input  logic i2c_sda_i,
  output logic i2c_sda_o,
  output logic i2c_sda_en_o,

  // External AXI mailbox access
  input  top_pkg::axi_req_t  axi_mailbox_req_i,  // TODO: Adapt type to surrounding system.
  output top_pkg::axi_resp_t axi_mailbox_resp_o, // TODO: Adapt type to surrounding system.

  // Mailbox IRQ out
  output logic mailbox_ext_irq_o,

  // SPI device receive and transmit.
  input  logic       spi_device_sck_i,
  input  logic       spi_device_csb_i,
  output logic [3:0] spi_device_sd_o,
  output logic [3:0] spi_device_sd_en_o,
  input  logic [3:0] spi_device_sd_i,
  input  logic       spi_device_tpm_csb_i,

  // SPI host receive and transmit.
  output logic                    spi_host_sck_o,
  output logic                    spi_host_sck_en_o,
  output logic [SPIHostNumCS-1:0] spi_host_csb_o,
  output logic [SPIHostNumCS-1:0] spi_host_csb_en_o,
  output logic [             3:0] spi_host_sd_o,
  output logic [             3:0] spi_host_sd_en_o,
  input  logic [             3:0] spi_host_sd_i,

  // DRAM AXI interface.
  output top_pkg::axi_dram_req_t  dram_req_o,
  input  top_pkg::axi_dram_resp_t dram_resp_i
);

  // Local parameters.
  localparam int unsigned SramMemSize    = 128 * 1024; // 128 KiB
  localparam int unsigned TlDataWidth    = top_pkg::TL_DW;
  localparam int unsigned AxiAddrOffset  = $clog2(top_pkg::AxiDataWidth / 8);
  localparam int unsigned SramAddrWidth  = $clog2(SramMemSize) - AxiAddrOffset;
  localparam int unsigned GpioIrqs       = 32;
  localparam int unsigned UartIrqs       = 9;
  localparam int unsigned I2cIrqs        = 15;
  localparam int unsigned SPIDeviceIrqs  = 8;
  localparam int unsigned SPIHostIrqs    = 2;
  localparam int unsigned KmacNumAppIntf = 1;

  // CVA6 configuration
  function automatic config_pkg::cva6_cfg_t build_cva6_config(config_pkg::cva6_user_cfg_t CVA6UserCfg);
    config_pkg::cva6_user_cfg_t cfg = CVA6UserCfg;
    cfg.RVZiCond              = bit'(0);
    cfg.CvxifEn               = bit'(0);
    cfg.NrNonIdempotentRules  = unsigned'(1);
    cfg.NonIdempotentAddrBase = 1024'({64'b0});
    cfg.NonIdempotentLength   = 1024'({top_pkg::SRAMBase});
    return build_config_pkg::build_config(cfg);
  endfunction

  localparam config_pkg::cva6_cfg_t CVA6Cfg = build_cva6_config(cva6_config_pkg::cva6_cfg);
  cva6_cheri_pkg::cap_pcc_t boot_cap;
  always_comb begin : gen_boot_cap
    boot_cap                = cva6_cheri_pkg::PCC_ROOT_CAP;
    boot_cap.addr           = top_pkg::SRAMBase + 'h80;
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
    '{ idx: top_pkg::RomCtrlMem, start_addr: top_pkg::RomCtrlMemBase, end_addr: top_pkg::RomCtrlMemBase + top_pkg::RomCtrlMemLength },
    '{ idx: top_pkg::SRAM,       start_addr: top_pkg::SRAMBase,       end_addr: top_pkg::SRAMBase       + top_pkg::SRAMLength       },
    '{ idx: top_pkg::Mailbox,    start_addr: top_pkg::MailboxBase,    end_addr: top_pkg::MailboxBase    + top_pkg::MailboxLength    },
    '{ idx: top_pkg::TlCrossbar, start_addr: top_pkg::TlCrossbarBase, end_addr: top_pkg::TlCrossbarBase + top_pkg::TlCrossbarLength },
    '{ idx: top_pkg::DRAM,       start_addr: top_pkg::DRAMBase,       end_addr: top_pkg::DRAMBase       + top_pkg::DRAMUsableLength }
  };

  // TileLink signals.
  // TL Xbar
  tlul_pkg::tl_h2d_t tl_axi_xbar_h2d;
  tlul_pkg::tl_d2h_t tl_axi_xbar_d2h;
  tlul_pkg::tl_h2d_t tl_gpio_h2d;
  tlul_pkg::tl_d2h_t tl_gpio_d2h;
  tlul_pkg::tl_h2d_t tl_clkmgr_h2d;
  tlul_pkg::tl_d2h_t tl_clkmgr_d2h;
  tlul_pkg::tl_h2d_t tl_rstmgr_h2d;
  tlul_pkg::tl_d2h_t tl_rstmgr_d2h;
  tlul_pkg::tl_h2d_t tl_pwrmgr_h2d;
  tlul_pkg::tl_d2h_t tl_pwrmgr_d2h;
  tlul_pkg::tl_h2d_t tl_rom_ctrl_regs_h2d;
  tlul_pkg::tl_d2h_t tl_rom_ctrl_regs_d2h;
  tlul_pkg::tl_h2d_t tl_uart_h2d;
  tlul_pkg::tl_d2h_t tl_uart_d2h;
  tlul_pkg::tl_h2d_t tl_i2c_h2d;
  tlul_pkg::tl_d2h_t tl_i2c_d2h;
  tlul_pkg::tl_h2d_t tl_timer_h2d;
  tlul_pkg::tl_d2h_t tl_timer_d2h;
  tlul_pkg::tl_h2d_t tl_plic_h2d;
  tlul_pkg::tl_d2h_t tl_plic_d2h;
  tlul_pkg::tl_h2d_t tl_spi_device_h2d;
  tlul_pkg::tl_d2h_t tl_spi_device_d2h;
  tlul_pkg::tl_h2d_t tl_spi_host_h2d;
  tlul_pkg::tl_d2h_t tl_spi_host_d2h;
  // TL ROM
  tlul_pkg::tl_h2d_t tl_rom_ctrl_mem_h2d;
  tlul_pkg::tl_d2h_t tl_rom_ctrl_mem_d2h;

  // 64-bit memory format signals
  logic                                 mem64_tl_xbar_req;
  logic                                 mem64_tl_xbar_gnt;
  logic                                 mem64_tl_xbar_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] mem64_tl_xbar_be;
  logic [top_pkg::AxiAddrWidth-1:0]     mem64_tl_xbar_addr;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_tl_xbar_wdata;
  logic                                 mem64_tl_xbar_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_tl_xbar_rdata;

  logic                                 mem64_tl_rom_mem_req;
  logic                                 mem64_tl_rom_mem_gnt;
  logic                                 mem64_tl_rom_mem_we;
  logic [(top_pkg::AxiDataWidth/8)-1:0] mem64_tl_rom_mem_be;
  logic [top_pkg::AxiAddrWidth-1:0]     mem64_tl_rom_mem_addr;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_tl_rom_mem_wdata;
  logic                                 mem64_tl_rom_mem_rvalid;
  logic [top_pkg::AxiDataWidth-1:0]     mem64_tl_rom_mem_rdata;

  // 32-bit memory format signals
  logic                       mem32_tl_xbar_req;
  logic                       mem32_tl_xbar_gnt;
  logic                       mem32_tl_xbar_we;
  logic [(TlDataWidth/8)-1:0] mem32_tl_xbar_be;
  logic [top_pkg::TL_AW-1:0]  mem32_tl_xbar_addr;
  logic [TlDataWidth-1:0]     mem32_tl_xbar_wdata;
  logic                       mem32_tl_xbar_rvalid;
  logic [TlDataWidth-1:0]     mem32_tl_xbar_rdata;

  logic                       mem32_tl_rom_mem_req;
  logic                       mem32_tl_rom_mem_gnt;
  logic                       mem32_tl_rom_mem_we;
  logic [(TlDataWidth/8)-1:0] mem32_tl_rom_mem_be;
  logic [top_pkg::TL_AW-1:0]  mem32_tl_rom_mem_addr;
  logic [TlDataWidth-1:0]     mem32_tl_rom_mem_wdata;
  logic                       mem32_tl_rom_mem_rvalid;
  logic [TlDataWidth-1:0]     mem32_tl_rom_mem_rdata;

  // AXI signals
  top_pkg::axi_req_t  [xbar_cfg.NoSlvPorts-1:0] xbar_host_req;
  top_pkg::axi_resp_t [xbar_cfg.NoSlvPorts-1:0] xbar_host_resp;
  top_pkg::axi_req_t  [xbar_cfg.NoMstPorts-1:0] xbar_device_req;
  top_pkg::axi_resp_t [xbar_cfg.NoMstPorts-1:0] xbar_device_resp;
  top_pkg::axi_req_t                            dram_post_atomics_req;
  top_pkg::axi_resp_t                           dram_post_atomics_resp;
  top_pkg::axi_req_t                            dram_cut_req;
  top_pkg::axi_resp_t                           dram_cut_resp;
  top_pkg::axi_req_t                            tag_controller_isolated_req;
  top_pkg::axi_resp_t                           tag_controller_isolated_resp;

  // Tag controller isolation signals and registers
  logic tag_controller_isolate;
  logic tag_controller_isolate_reg;
  logic tag_controller_isolated;

  // IP block raised interrupts
  logic [GpioIrqs-1:0]      gpio_interrupts;
  logic [UartIrqs-1:0]      uart_interrupts;
  logic [I2cIrqs-1:0]       i2c_interrupts;
  logic [SPIDeviceIrqs-1:0] spi_device_interrupts;
  logic [SPIHostIrqs-1:0]   spi_host_interrupts;

  // Interrupt lines to PLIC
  // Each IP block has a single interrupt line to the PLIC and software shall consult the intr_state
  // register within the block itself to identify the interrupt source(s).
  logic gpio_irq;
  logic mailbox_main_irq;
  logic uart_irq;
  logic i2c_irq;
  logic spi_device_irq;
  logic spi_host_irq;
  logic pwrmgr_wakeup_irq;

  always_comb begin
    // Single interrupt line per IP block.
    gpio_irq       = |gpio_interrupts;
    uart_irq       = |uart_interrupts;
    i2c_irq        = |i2c_interrupts;
    spi_device_irq = |spi_device_interrupts;
    spi_host_irq   = |spi_host_interrupts;
  end

  // Interrupt vector
  logic [31:0] intr_vector;

  assign intr_vector[31 : 12] = '0;  // Reserved for future use.
  assign intr_vector[     11] = mailbox_main_irq;
  assign intr_vector[     10] = pwrmgr_wakeup_irq;
  assign intr_vector[      9] = gpio_irq;
  assign intr_vector[      8] = uart_irq;
  assign intr_vector[      7] = spi_device_irq;
  assign intr_vector[      6] = i2c_irq;
  assign intr_vector[      5] = spi_host_irq;
  assign intr_vector[ 4 :  0] = '0;  // Reserved for future use.

  // Interrupts to the CVA6
  logic       intr_timer;
  logic [1:0] intr;

  // Signals to intercept AXI traffic from CVA6 for DV puprose
  top_pkg::axi_req_t  cva6_to_sim_req;
  top_pkg::axi_resp_t sim_to_cva6_resp;

  // Define the signals used by the clock, reset and power managers.
  clkmgr_pkg::clkmgr_cg_en_t  clkmgr_cg_en;
  clkmgr_pkg::clkmgr_out_t    clkmgr_clocks;
  rstmgr_pkg::rstmgr_out_t    rstmgr_resets;
  rstmgr_pkg::rstmgr_rst_en_t rstmgr_rst_en;
  prim_mubi_pkg::mubi4_t      rstmgr_sw_rst_req;
  pwrmgr_pkg::pwr_clk_req_t   pwrmgr_pwr_clk_req;
  pwrmgr_pkg::pwr_clk_rsp_t   pwrmgr_pwr_clk_rsp;
  pwrmgr_pkg::pwr_rst_req_t   pwrmgr_pwr_rst_req;
  pwrmgr_pkg::pwr_rst_rsp_t   pwrmgr_pwr_rst_rsp;
  logic                       pwrmgr_strap_en;

  // Define AXI Lite signals for the mailbox
  top_pkg::axi_lite_req_t  mailbox_main_req;
  top_pkg::axi_lite_resp_t mailbox_main_resp;
  top_pkg::axi_lite_req_t  mailbox_ext_req;
  top_pkg::axi_lite_resp_t mailbox_ext_resp;

  // rom_ctrl related signals
  prim_rom_pkg::rom_cfg_t                  rom_cfg;
  rom_ctrl_pkg::pwrmgr_data_t              rom_ctrl_pwrmgr_data;
  rom_ctrl_pkg::keymgr_data_t              rom_ctrl_keymgr_data;
  kmac_pkg::app_req_t [KmacNumAppIntf-1:0] kmac_app_req;
  kmac_pkg::app_rsp_t [KmacNumAppIntf-1:0] kmac_app_rsp;

  // Unused rom_ctrl signals
  logic unused_rom_ctrl_output;
  assign unused_rom_ctrl_output = (|rom_ctrl_keymgr_data) | (|kmac_app_req) | (|kmac_app_rsp);

  // Assigning default values
  assign rom_cfg = prim_rom_pkg::ROM_CFG_DEFAULT;
  for (genvar i = 0; i < KmacNumAppIntf; i++) begin : g_kmac_app_default
    assign kmac_app_req[i] = kmac_pkg::APP_REQ_DEFAULT;
    assign kmac_app_rsp[i] = kmac_pkg::APP_RSP_DEFAULT;
  end

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
    .clk_i         (clkmgr_clocks.clk_main_infra),
    .rst_ni        (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .boot_addr_i   (boot_cap),
    .hart_id_i     ('0),
    .irq_i         (intr),
    .ipi_i         (1'b0),
    .time_irq_i    (intr_timer),
    .debug_req_i   (1'b0),
    .rvfi_probes_o ( ),
    .cvxif_req_o   ( ),
    .cvxif_resp_i  ('0),
    .noc_req_o     (cva6_to_sim_req),
    .noc_resp_i    (sim_to_cva6_resp)
  );

  // Interception point for connecting simulation SRAM by disconnecting the AXI output. The
  // disconnection is done only if `SYNTHESIS is NOT defined AND `INST_SIM_SRAM is defined.
  // This define is used only for Verilator as it does not support forces.
`ifdef INST_SIM_SRAM
`ifdef SYNTHESIS
  // Induce a compilation error by instantiating a non-existent module.
  illegal_preprocessor_branch_taken u_illegal_preprocessor_branch_taken ();
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
    .clk_i  (clkmgr_clocks.clk_main_infra),
    .rst_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

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
    .clk_i                (clkmgr_clocks.clk_main_infra),
    .rst_ni               (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .test_i               (1'b0),
    .slv_ports_req_i      (xbar_host_req),
    .slv_ports_resp_o     (xbar_host_resp),
    .mst_ports_req_o      (xbar_device_req),
    .mst_ports_resp_i     (xbar_device_resp),
    .addr_map_i           (addr_map),
    .en_default_mst_port_i('0),
    .default_mst_port_i   ('0)
  );

  // Mailbox: main AXI to AXI Lite adapter
  axi_to_axi_lite #(
    .AxiAddrWidth   ( top_pkg::AxiAddrWidth ),
    .AxiDataWidth   ( top_pkg::AxiDataWidth ),
    .AxiIdWidth     ( top_pkg::AxiIdWidth   ),
    .AxiUserWidth   ( top_pkg::AxiUserWidth ),
    .AxiMaxWriteTxns( 32'd1 ),
    .AxiMaxReadTxns ( 32'd1 ),
    .FullBW         ( 32'd1 ), // TODO: Tune me
    .FallThrough    ( 32'd0 ), // TODO: Tune me
    .full_req_t     ( top_pkg::axi_req_t  ),
    .full_resp_t    ( top_pkg::axi_resp_t ),
    .lite_req_t     ( top_pkg::axi_lite_req_t  ),
    .lite_resp_t    ( top_pkg::axi_lite_resp_t )
  ) u_axi_to_axi_lite_mailbox_main (
    .clk_i      ( clkmgr_clocks.clk_main_infra ),
    .rst_ni     ( rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel] ),
    .test_i     ( 1'b0 ),
    .slv_req_i  ( xbar_device_req[top_pkg::Mailbox]  ),
    .slv_resp_o ( xbar_device_resp[top_pkg::Mailbox] ),
    .mst_req_o  ( mailbox_main_req  ),
    .mst_resp_i ( mailbox_main_resp )
  );

  // Mailbox: external AXI to AXI Lite adapter
  axi_to_axi_lite #(
    .AxiAddrWidth   ( top_pkg::AxiAddrWidth ),
    .AxiDataWidth   ( top_pkg::AxiDataWidth ),
    .AxiIdWidth     ( top_pkg::AxiIdWidth   ),
    .AxiUserWidth   ( top_pkg::AxiUserWidth ),
    .AxiMaxWriteTxns( 32'd1 ),
    .AxiMaxReadTxns ( 32'd1 ),
    .FullBW         ( 32'd1 ), // TODO: Tune me
    .FallThrough    ( 32'd0 ), // TODO: Tune me
    .full_req_t     ( top_pkg::axi_req_t  ),
    .full_resp_t    ( top_pkg::axi_resp_t ),
    .lite_req_t     ( top_pkg::axi_lite_req_t  ),
    .lite_resp_t    ( top_pkg::axi_lite_resp_t )
  ) u_axi_to_axi_lite_mailbox_ext (
    .clk_i      ( clkmgr_clocks.clk_main_infra ),
    .rst_ni     ( rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel] ),
    .test_i     ( 1'b0 ),
    .slv_req_i  ( axi_mailbox_req_i  ),
    .slv_resp_o ( axi_mailbox_resp_o ),
    .mst_req_o  ( mailbox_ext_req  ),
    .mst_resp_i ( mailbox_ext_resp )
  );

  // Mailbox
  axi_lite_mailbox #(
    .MailboxDepth ( 32'd3 ), // TODO: Tune me
    .AxiAddrWidth ( top_pkg::AxiAddrWidth ),
    .AxiDataWidth ( top_pkg::AxiDataWidth ),
    .req_lite_t   ( top_pkg::axi_lite_req_t  ),
    .resp_lite_t  ( top_pkg::axi_lite_resp_t ),
    .addr_t       ( top_pkg::addr_t )
  ) u_axi_lite_mailbox (
    .clk_i       ( clkmgr_clocks.clk_main_infra ),
    .rst_ni      ( rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel] ),
    .test_i      ( 1'b0 ),
    .slv_reqs_i  ( { mailbox_ext_req,   mailbox_main_req  } ),
    .slv_resps_o ( { mailbox_ext_resp,  mailbox_main_resp } ),
    .irq_o       ( { mailbox_ext_irq_o, mailbox_main_irq  } ),
    .base_addr_i ( { top_pkg::MailboxExtBaseAddr, top_pkg::MailboxBase } )
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
    .clk_i  (clkmgr_clocks.clk_main_infra),
    .rst_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

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
    .clk_i  (clkmgr_clocks.clk_main_infra),
    .rst_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

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
    .clk_i  (clkmgr_clocks.clk_main_infra),
    .rst_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

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
  xbar_peri u_xbar_peri (
    // Clock and reset.
    .clk_main_i  (clkmgr_clocks.clk_main_infra),
    .clk_io_i    (clkmgr_clocks.clk_io_infra),
    .rst_main_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .rst_io_ni   (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

    // Host interfaces.
    .tl_axi_xbar_i (tl_axi_xbar_h2d),
    .tl_axi_xbar_o (tl_axi_xbar_d2h),

    // Device interfaces.
    .tl_gpio_o          (tl_gpio_h2d),
    .tl_gpio_i          (tl_gpio_d2h),
    .tl_clkmgr_o        (tl_clkmgr_h2d),
    .tl_clkmgr_i        (tl_clkmgr_d2h),
    .tl_rstmgr_o        (tl_rstmgr_h2d),
    .tl_rstmgr_i        (tl_rstmgr_d2h),
    .tl_pwrmgr_o        (tl_pwrmgr_h2d),
    .tl_pwrmgr_i        (tl_pwrmgr_d2h),
    .tl_rom_ctrl_regs_o (tl_rom_ctrl_regs_h2d),
    .tl_rom_ctrl_regs_i (tl_rom_ctrl_regs_d2h),
    .tl_uart_o          (tl_uart_h2d),
    .tl_uart_i          (tl_uart_d2h),
    .tl_i2c_o           (tl_i2c_h2d),
    .tl_i2c_i           (tl_i2c_d2h),
    .tl_spi_device_o    (tl_spi_device_h2d),
    .tl_spi_device_i    (tl_spi_device_d2h),
    .tl_timer_o         (tl_timer_h2d),
    .tl_timer_i         (tl_timer_d2h),
    .tl_spi_host_o      (tl_spi_host_h2d),
    .tl_spi_host_i      (tl_spi_host_d2h),
    .tl_plic_o          (tl_plic_h2d),
    .tl_plic_i          (tl_plic_d2h),

    .scanmode_i (prim_mubi_pkg::MuBi4False)
  );

  // Instantiate GPIO block from IP template
  gpio #(
    .GpioAsyncOn(1), // inputs may be directly connected to external I/O or other SoC clock domains
    .GpioAsHwStrapsEn(0) // straps not our problem when we are only a SoC subsystem
  ) u_gpio (
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),

    // Strap ports.
    .strap_en_i       (pwrmgr_strap_en),
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
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

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

  // Instantiate I^2C controller/target
  i2c #(
    .InputDelayCycles(0) // note: may not be true for all tops
  ) u_i2c (
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o ( ),

    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),
    .lsio_trigger_o  ( ),

    // Unused RAM config ports
    .ram_cfg_i     (prim_ram_1p_pkg::RAM_1P_CFG_DEFAULT),
    .ram_cfg_rsp_o ( ),

    // I^2C interface.
    .cio_scl_i     (i2c_scl_i),
    .cio_scl_o     (i2c_scl_o),
    .cio_scl_en_o  (i2c_scl_en_o),
    .cio_sda_i     (i2c_sda_i),
    .cio_sda_o     (i2c_sda_o),
    .cio_sda_en_o  (i2c_sda_en_o),

    // Inter-module signals.
    .tl_i (tl_i2c_h2d),
    .tl_o (tl_i2c_d2h),

    // Interrupts.
    .intr_fmt_threshold_o     (i2c_interrupts[0]),
    .intr_rx_threshold_o      (i2c_interrupts[1]),
    .intr_acq_threshold_o     (i2c_interrupts[2]),
    .intr_rx_overflow_o       (i2c_interrupts[3]),
    .intr_controller_halt_o   (i2c_interrupts[4]),
    .intr_scl_interference_o  (i2c_interrupts[5]),
    .intr_sda_interference_o  (i2c_interrupts[6]),
    .intr_stretch_timeout_o   (i2c_interrupts[7]),
    .intr_sda_unstable_o      (i2c_interrupts[8]),
    .intr_cmd_complete_o      (i2c_interrupts[9]),
    .intr_tx_stretch_o        (i2c_interrupts[10]),
    .intr_tx_threshold_o      (i2c_interrupts[11]),
    .intr_acq_stretch_o       (i2c_interrupts[12]),
    .intr_unexp_stop_o        (i2c_interrupts[13]),
    .intr_host_timeout_o      (i2c_interrupts[14])
  );

  // Instantiate timer
  rv_timer u_timer (
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

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
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

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
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

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

  // Instantiate SPI host to talk to external flash or SD card.
  spi_host #(
    .NumCS ( SPIHostNumCS )
  ) u_spi_host (
    // Clock and reset.
    .clk_i  (clkmgr_clocks.clk_io_infra),
    .rst_ni (rstmgr_resets.rst_io_n[rstmgr_pkg::Domain0Sel]),

    // TileLink bus connections.
    .tl_i (tl_spi_host_h2d),
    .tl_o (tl_spi_host_d2h),

    // Alerts and RACL.
    .alert_rx_i      (prim_alert_pkg::ALERT_RX_DEFAULT),
    .alert_tx_o      ( ),
    .racl_policies_i (top_racl_pkg::RACL_POLICY_VEC_DEFAULT),
    .racl_error_o    ( ),

    // SPI top-level signals.
    .cio_sck_o    (spi_host_sck_o),
    .cio_sck_en_o (spi_host_sck_en_o),
    .cio_csb_o    (spi_host_csb_o),
    .cio_csb_en_o (spi_host_csb_en_o),
    .cio_sd_o     (spi_host_sd_o),
    .cio_sd_en_o  (spi_host_sd_en_o),
    .cio_sd_i     (spi_host_sd_i),

    // Passthrough and interrupt interfaces.
    .passthrough_i  (spi_device_pkg::PASSTHROUGH_REQ_DEFAULT),
    .passthrough_o  ( ),
    .lsio_trigger_o ( ),

    // Interrupts.
    .intr_error_o     (spi_host_interrupts[0]),
    .intr_spi_event_o (spi_host_interrupts[1])
  );

  ///////////////
  // Managers. //
  ///////////////

  // These managers include clock, power and reset.
  // These are all in the always on clock domain.

  clkmgr u_clkmgr (
    // Alerts.
    .alert_tx_o ( ),
    .alert_rx_i ('{default: prim_alert_pkg::ALERT_RX_DEFAULT}),

    // Inter-module signals.
    .clocks_o    (clkmgr_clocks),
    .cg_en_o     (clkmgr_cg_en),
    .jitter_en_o ( ),
    .pwr_i       (pwrmgr_pwr_clk_req),
    .pwr_o       (pwrmgr_pwr_clk_rsp),
    .idle_i      (prim_mubi_pkg::MuBi4False),
    .tl_i        (tl_clkmgr_h2d),
    .tl_o        (tl_clkmgr_d2h),
    .scanmode_i  (prim_mubi_pkg::MuBi4False),

    // Clock and reset connections.
    .clk_i            (clkmgr_clocks.clk_io_powerup),
    .clk_main_i       (clk_i),
    .clk_io_i         (clk_i),
    .clk_aon_i        (clk_i),
    .rst_shadowed_ni  (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_ni           (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_aon_ni       (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_io_ni        (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_main_ni      (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_root_ni      (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_root_io_ni   (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_root_main_ni (rstmgr_resets.rst_por_n[rstmgr_pkg::DomainAonSel])
  );

  pwrmgr u_pwrmgr (
    // Interrupt.
    .intr_wakeup_o (pwrmgr_wakeup_irq),

    // Alerts.
    .alert_tx_o ( ),
    .alert_rx_i (prim_alert_pkg::ALERT_RX_DEFAULT),

    // Inter-module signals.
    .pwr_rst_o        (pwrmgr_pwr_rst_req),
    .pwr_rst_i        (pwrmgr_pwr_rst_rsp),
    .pwr_clk_o        (pwrmgr_pwr_clk_req),
    .pwr_clk_i        (pwrmgr_pwr_clk_rsp),
    .pwr_ast_i        (pwrmgr_pkg::PWR_AST_RSP_DEFAULT),
    .pwr_ast_o        ( ),
    .pwr_otp_i        (pwrmgr_pkg::PWR_OTP_RSP_DEFAULT), // Default to done and idle.
    .pwr_otp_o        ( ),
    .pwr_lc_o         ( ),
    .pwr_lc_i         (lc_ctrl_pkg::PWR_LC_RSP_DEFAULT), // Default to initialised and done.
    .pwr_nvm_i        (pwrmgr_pkg::PWR_NVM_DEFAULT), // Default to idle.
    .esc_rst_tx_i     (prim_esc_pkg::ESC_RX_DEFAULT),
    .esc_rst_rx_o     ( ),
    .pwr_cpu_i        ('0), // Core is not sleeping.
    .fetch_en_o       ( ), // No fetch enable on CVA6.
    .wakeups_i        ('0), // Always wake up immediately.
    .rstreqs_i        ('0), // No reset requests yet.
    .ndmreset_req_i   ('0), // No debug module yet.
    .strap_o          (pwrmgr_strap_en),
    .low_power_o      ( ), // Low power not yet supported.
    .rom_ctrl_i       (rom_ctrl_pwrmgr_data),
    .lc_dft_en_i      (lc_ctrl_pkg::Off),
    .lc_hw_debug_en_i (lc_ctrl_pkg::On),
    .sw_rst_req_i     (rstmgr_sw_rst_req),
    .tl_i             (tl_pwrmgr_h2d),
    .tl_o             (tl_pwrmgr_d2h),

    // Clock and reset connections.
    .clk_i       (clkmgr_clocks.clk_io_powerup),
    .clk_slow_i  (clkmgr_clocks.clk_aon_powerup),
    .clk_lc_i    (clkmgr_clocks.clk_io_powerup),
    .clk_esc_i   (clkmgr_clocks.clk_io_powerup),
    .rst_ni      (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_main_ni (rstmgr_resets.rst_por_aon_n[rstmgr_pkg::Domain0Sel]),
    .rst_lc_ni   (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_esc_ni  (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_slow_ni (rstmgr_resets.rst_por_aon_n[rstmgr_pkg::DomainAonSel])
  );

  rstmgr u_rstmgr (
    .alert_tx_o ( ),
    .alert_rx_i ('{default: prim_alert_pkg::ALERT_RX_DEFAULT}),

    // Inter-module signals
    .por_n_i      ({rst_ni, rst_ni}),
    .pwr_i        (pwrmgr_pwr_rst_req),
    .pwr_o        (pwrmgr_pwr_rst_rsp),
    .resets_o     (rstmgr_resets),
    .rst_en_o     (rstmgr_rst_en),
    .alert_dump_i (alert_handler_pkg::ALERT_CRASHDUMP_DEFAULT),
    .cpu_dump_i   ('0),
    .sw_rst_req_o (rstmgr_sw_rst_req),
    .tl_i         (tl_rstmgr_h2d),
    .tl_o         (tl_rstmgr_d2h),
    .scanmode_i   (prim_mubi_pkg::MuBi4False),
    .scan_rst_ni  ('1),

    // Clock and reset connections
    .clk_i      (clkmgr_clocks.clk_io_powerup),
    .clk_por_i  (clkmgr_clocks.clk_io_powerup),
    .clk_aon_i  (clkmgr_clocks.clk_aon_powerup),
    .clk_main_i (clkmgr_clocks.clk_main_powerup),
    .clk_io_i   (clkmgr_clocks.clk_io_powerup),
    .rst_ni     (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel]),
    .rst_por_ni (rstmgr_resets.rst_por_io_n[rstmgr_pkg::DomainAonSel])
  );

  // Mark outputs as unused for the current setup of the managers.
  logic unused_manager_output;
  assign unused_manager_output =
    clkmgr_clocks.clk_main_hint | clkmgr_clocks.clk_io_peri |
    (|clkmgr_cg_en) |
    (|rstmgr_resets.rst_por_n) | (|rstmgr_resets.rst_spi_device_n) | (|rstmgr_resets.rst_spi_host_n) | (|rstmgr_resets.rst_i2c_n) |
    (|rstmgr_rst_en);

  // Combine response and request between crossbar and atomics wrapper.
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( top_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( top_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( top_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( top_pkg::AxiUserWidth )
  ) xbar_device_dram();
  `AXI_ASSIGN_FROM_REQ(xbar_device_dram, xbar_device_req[top_pkg::DRAM])
  `AXI_ASSIGN_TO_RESP(xbar_device_resp[top_pkg::DRAM], xbar_device_dram)

  // Split response and request between atomics wrapper and cut.
  AXI_BUS #(
    .AXI_ADDR_WIDTH ( top_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH ( top_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH   ( top_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH ( top_pkg::AxiUserWidth )
  ) dram_post_atomics();
  `AXI_ASSIGN_TO_REQ(dram_post_atomics_req, dram_post_atomics)
  `AXI_ASSIGN_FROM_RESP(dram_post_atomics, dram_post_atomics_resp)

  // AXI atomics wrapper to handle swaps before going to the tag controller.
  axi_riscv_atomics_wrap #(
    .AXI_ADDR_WIDTH     ( top_pkg::AxiAddrWidth ),
    .AXI_DATA_WIDTH     ( top_pkg::AxiDataWidth ),
    .AXI_ID_WIDTH       ( top_pkg::AxiIdWidth   ),
    .AXI_USER_WIDTH     ( top_pkg::AxiUserWidth ),
    .AXI_MAX_WRITE_TXNS ( 1                     ),
    .RISCV_WORD_WIDTH   ( 64                    )
  ) u_axi_riscv_atomics (
    .clk_i  (clkmgr_clocks.clk_main_infra),
    .rst_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .slv    (xbar_device_dram),
    .mst    (dram_post_atomics)
  );

  // Cut combinatorial path between atomics and isolation.
  axi_cut #(
    .aw_chan_t  ( top_pkg::axi_aw_chan_t ),
    .w_chan_t   ( top_pkg::axi_w_chan_t  ),
    .b_chan_t   ( top_pkg::axi_b_chan_t  ),
    .ar_chan_t  ( top_pkg::axi_ar_chan_t ),
    .r_chan_t   ( top_pkg::axi_r_chan_t  ),
    .axi_req_t  ( top_pkg::axi_req_t     ),
    .axi_resp_t ( top_pkg::axi_resp_t    )
  ) u_axi_cut (
    .clk_i      (clkmgr_clocks.clk_main_infra),
    .rst_ni     (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .slv_req_i  (dram_post_atomics_req),
    .slv_resp_o (dram_post_atomics_resp),
    .mst_req_o  (dram_cut_req),
    .mst_resp_i (dram_cut_resp)
  );

  // AXI Isolator for tag controller
  axi_isolate #(
    .TerminateTransaction ( 1'b0                  ),
    .AtopSupport          ( 1'b1                  ),
    .AxiAddrWidth         ( top_pkg::AxiAddrWidth ),
    .AxiDataWidth         ( top_pkg::AxiDataWidth ),
    .AxiIdWidth           ( top_pkg::AxiIdWidth   ),
    .AxiUserWidth         ( top_pkg::AxiUserWidth ),
    .axi_req_t            ( top_pkg::axi_req_t    ),
    .axi_resp_t           ( top_pkg::axi_resp_t   )
  ) u_tag_controller_isolate (
    .clk_i      (clkmgr_clocks.clk_main_infra),
    .rst_ni     (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .slv_req_i  (dram_cut_req),
    .slv_resp_o (dram_cut_resp),
    .mst_req_o  (tag_controller_isolated_req),
    .mst_resp_i (tag_controller_isolated_resp),
    .isolate_i  (tag_controller_isolate | tag_controller_isolate_reg),
    .isolated_o (tag_controller_isolated)
  );

  // Tag controller isolation logic
  assign tag_controller_isolate = (dram_cut_req.ar_valid && dram_cut_resp.ar_ready) ||
                                  (dram_cut_req.aw_valid && dram_cut_resp.aw_ready);

  always_ff @(posedge clkmgr_clocks.clk_main_infra or negedge rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]) begin
    if (!rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]) tag_controller_isolate_reg <= 1'b0;
    else if (tag_controller_isolate)                       tag_controller_isolate_reg <= 1'b1;
    else if (tag_controller_isolated)                      tag_controller_isolate_reg <= 1'b0;
  end

  // Define types for tag controller
  `REG_BUS_TYPEDEF_ALL(conf, logic [31:0], logic [31:0], logic [3:0])

  // Instantiate CHERI tag controller for DRAM
  axi_tagctrl_reg_wrap #(
    .DRAMMemBase      ( 32'(top_pkg::DRAMBase)            ),
    .DRAMMemLength    ( 32'(top_pkg::DRAMPhysicalLength)  ),
    .CapSize          ( top_pkg::CapSizeBits              ),
    .TagCacheMemBase  ( 32'(top_pkg::TagCacheMemBase)     ),
    .SetAssociativity ( top_pkg::TagCacheSetAssociativity ),
    .NumLines         ( top_pkg::TagCacheNumLines         ),
    .NumBlocks        ( top_pkg::TagCacheNumBlocks        ),
    .AxiIdWidth       ( top_pkg::AxiIdWidth               ),
    .AxiAddrWidth     ( top_pkg::AxiAddrWidth             ),
    .AxiDataWidth     ( top_pkg::AxiDataWidth             ),
    .AxiUserWidth     ( top_pkg::AxiUserWidth             ),
    .slv_req_t        ( top_pkg::axi_req_t                ),
    .slv_resp_t       ( top_pkg::axi_resp_t               ),
    .mst_req_t        ( top_pkg::axi_dram_req_t           ), // ID is 1 bit wider than normal AXI types
    .mst_resp_t       ( top_pkg::axi_dram_resp_t          ),
    .reg_req_t        ( conf_req_t                        ),
    .reg_resp_t       ( conf_rsp_t                        ),
    .rule_full_t      ( axi_pkg::xbar_rule_64_t           )
  ) u_tag_controller (
    .clk_i               (clkmgr_clocks.clk_main_infra),
    .rst_ni              (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .test_i              ('0),
    .slv_req_i           (tag_controller_isolated_req),
    .slv_resp_o          (tag_controller_isolated_resp),
    .mst_req_o           (dram_req_o),
    .mst_resp_i          (dram_resp_i),
    .conf_req_i          ('0),
    .conf_resp_o         ( ),
    .cached_start_addr_i (top_pkg::DRAMBase),
    .cached_end_addr_i   (top_pkg::TagCacheMemBase)
  );

  // TL ROM
  // AXI to 64-bit mem for TLUL ROM
  axi_to_mem #(
    .axi_req_t  ( top_pkg::axi_req_t    ),
    .axi_resp_t ( top_pkg::axi_resp_t   ),
    .AddrWidth  ( top_pkg::AxiAddrWidth ),
    .DataWidth  ( top_pkg::AxiDataWidth ),
    .IdWidth    ( top_pkg::AxiIdWidth   ),
    .NumBanks   ( 1                     )
  ) u_tl_rom_axi_to_mem (
    .clk_i      (clkmgr_clocks.clk_main_infra),
    .rst_ni     (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

    // AXI interface.
    .busy_o     ( ),
    .axi_req_i  (xbar_device_req[top_pkg::RomCtrlMem]),
    .axi_resp_o (xbar_device_resp[top_pkg::RomCtrlMem]),

    // Memory interface.
    .mem_req_o    (mem64_tl_rom_mem_req),
    .mem_gnt_i    (mem64_tl_rom_mem_gnt),
    .mem_addr_o   (mem64_tl_rom_mem_addr),
    .mem_wdata_o  (mem64_tl_rom_mem_wdata),
    .mem_strb_o   (mem64_tl_rom_mem_be),
    .mem_atop_o   ( ),
    .mem_we_o     (mem64_tl_rom_mem_we),
    .mem_rvalid_i (mem64_tl_rom_mem_rvalid),
    .mem_rdata_i  (mem64_tl_rom_mem_rdata)
  );

  // 64-bit mem to 32-bit mem for TLUL ROM
  mem_downsizer u_tl_rom_mem_downsizer (
    .clk_i      (clkmgr_clocks.clk_main_infra),
    .rst_ni     (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

    // 64-bit memory request in
    .mem64_req_i    (mem64_tl_rom_mem_req),
    .mem64_gnt_o    (mem64_tl_rom_mem_gnt),
    .mem64_we_i     (mem64_tl_rom_mem_we),
    .mem64_be_i     (mem64_tl_rom_mem_be),
    .mem64_addr_i   (mem64_tl_rom_mem_addr),
    .mem64_wdata_i  (mem64_tl_rom_mem_wdata),
    .mem64_rvalid_o (mem64_tl_rom_mem_rvalid),
    .mem64_rdata_o  (mem64_tl_rom_mem_rdata),

    // 32-bit memory request out
    .mem32_req_o    (mem32_tl_rom_mem_req),
    .mem32_gnt_i    (mem32_tl_rom_mem_gnt),
    .mem32_we_o     (mem32_tl_rom_mem_we),
    .mem32_be_o     (mem32_tl_rom_mem_be),
    .mem32_addr_o   (mem32_tl_rom_mem_addr),
    .mem32_wdata_o  (mem32_tl_rom_mem_wdata),
    .mem32_rvalid_i (mem32_tl_rom_mem_rvalid),
    .mem32_rdata_i  (mem32_tl_rom_mem_rdata)
  );

  // 32-bit mem to TLUL for TLUL ROM
  tlul_adapter_host #(
    .EnableDataIntgGen      ( 1 ),
    .EnableRspDataIntgCheck ( 1 )
  ) u_tl_rom_tlul_host_adapter (
    .clk_i      (clkmgr_clocks.clk_main_infra),
    .rst_ni     (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

    .req_i        (mem32_tl_rom_mem_req),
    .gnt_o        (mem32_tl_rom_mem_gnt),
    .addr_i       (mem32_tl_rom_mem_addr),
    .we_i         (mem32_tl_rom_mem_we),
    .wdata_i      (mem32_tl_rom_mem_wdata),
    .wdata_intg_i ('0),
    .be_i         (mem32_tl_rom_mem_be),
    .instr_type_i (prim_mubi_pkg::MuBi4True),
    .user_rsvd_i  ('0),

    .valid_o      (mem32_tl_rom_mem_rvalid),
    .rdata_o      (mem32_tl_rom_mem_rdata),
    .rdata_intg_o ( ),
    .err_o        ( ),
    .intg_err_o   ( ),

    .tl_o         (tl_rom_ctrl_mem_h2d),
    .tl_i         (tl_rom_ctrl_mem_d2h)
  );

  rom_ctrl # (
    .BootRomInitFile      ( RomInitFile ),
    .AlertAsyncOn         ( 1'b1        ),
    .AlertSkewCycles      ( 1           ),
    .FlopToKmac           ( 1'b0        ),
    .RndCnstScrNonce      ( '0          ),
    .RndCnstScrKey        ( '0          ),
    .SecDisableScrambling ( 1'b1        ),
    .MemSizeRom           ( 32'(top_pkg::RomCtrlMemLength) )
  ) u_rom_ctrl (
    // Clock and reset connections
    .clk_i  (clkmgr_clocks.clk_main_infra),
    .rst_ni (rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),

    // Allert Signals
    .alert_tx_o  ( ),
    .alert_rx_i  (prim_alert_pkg::ALERT_RX_DEFAULT),

    // Inter-module signals
    .rom_cfg_i      (rom_cfg),
    .pwrmgr_data_o  (rom_ctrl_pwrmgr_data),
    .keymgr_data_o  (rom_ctrl_keymgr_data),
    .kmac_data_o    (),
    .kmac_data_i    (),
    .rom_tl_i       (tl_rom_ctrl_mem_h2d),
    .rom_tl_o       (tl_rom_ctrl_mem_d2h),
    .regs_tl_i      (tl_rom_ctrl_regs_h2d),
    .regs_tl_o      (tl_rom_ctrl_regs_d2h)
  );

endmodule
