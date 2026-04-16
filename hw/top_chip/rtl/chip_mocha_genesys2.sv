// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module chip_mocha_genesys2 #(
  parameter RomInitFile  = "",
  parameter SramInitFile = ""
) (
  // Onboard 200MHz oscillator
  input  logic sysclk_200m_ni,
  input  logic sysclk_200m_pi,

  // External reset
  input  logic ext_rst_ni,
  input  logic ftdi_rst_ni,

  // GPIO - enough for the user switches and LEDs as a starting point
  input  logic [8:0] gpio_i,
  output logic [7:0] gpio_o,

  // UART
  input  logic uart_rx_i,
  output logic uart_tx_o,

  // I^2C - PMOD Header "JA"
  inout  logic i2c_scl_io,
  inout  logic i2c_sda_io,

  // SPI
  input  logic spi_device_sck_i,
  input  logic spi_device_csb_i,
  input  logic spi_device_sd_i,
  output logic spi_device_sd_o,
  output logic spien,

  // DDR3
  inout  wire  [31:0] ddr3_dq,
  inout  wire  [ 3:0] ddr3_dqs_n,
  inout  wire  [ 3:0] ddr3_dqs_p,
  output logic [14:0] ddr3_addr,
  output logic [ 2:0] ddr3_ba,
  output logic        ddr3_ras_n,
  output logic        ddr3_cas_n,
  output logic        ddr3_we_n,
  output logic        ddr3_reset_n,
  output logic [ 0:0] ddr3_ck_p,
  output logic [ 0:0] ddr3_ck_n,
  output logic [ 0:0] ddr3_cke,
  output logic [ 0:0] ddr3_cs_n,
  output logic [ 3:0] ddr3_dm,
  output logic [ 0:0] ddr3_odt
);
  // Local parameters
  localparam int unsigned InitialResetCycles = 4;

  // Internal clock signals
  logic clk_cfg;  // Free-running configuration clock
  logic clk_200m; // 200 MHz clock from MIG
  logic clk_50m;  // 50 MHz mocha clock generated from clk_200m

  // Internal reset signals
  logic fpga_rst_n_sync_cfg;     // FPGA initial reset, initial assertion, deassertion sync to clk_cfg
  logic mig_rst_n_sync_cfg;      // MIG system reset, async assertion, deassertion sync to clk_cfg
  logic mig_axi_rst_n_sync_200m; // MIG AXI reset, async assertion, deassertion sync to clk_200m
  logic rst_n_sync_50m;          // Mocha top reset, async assertion, deassertion sync to clk_50m

  // Initial reset shift register
  (* srl_style = "srl_reg" *) logic [InitialResetCycles-1:0] fpga_rst_n_shreg;

  // PLL lock signal
  logic pll_locked;

  // Output buffer value+enable signals and
  // bi-directional buffer input+output+direction signals
  logic [31:0] gpio_outputs;
  logic [31:0] gpio_en_outputs;
  logic        i2c_scl_input,     i2c_sda_input;
  logic        i2c_scl_output,    i2c_sda_output;
  logic        i2c_scl_en_output, i2c_sda_en_output;
  logic [3:0]  qspi_device_sdo;
  logic [3:0]  qspi_device_sdo_en;

  logic [3:0] spi_host_sd;
  logic [3:0] spi_host_sd_en;

  // AXI signals
  // Tag controller to CDC FIFO, synchronous to u_top_chip_system.clkmgr_clocks.clk_main_infra
  top_pkg::axi_dram_req_t  dram_req;
  top_pkg::axi_dram_resp_t dram_resp;
  // CDC FIFO to MIG, synchronous to clk_200m
  top_pkg::axi_dram_req_t  mig_req;
  top_pkg::axi_dram_resp_t mig_resp;

  // Clock generation
  clkgen_xil7series clk_gen (
    .clk_200m_i   (clk_200m),
    .clk_cfg_o    (clk_cfg),
    .pll_locked_o (pll_locked),
    .clk_50m_o    (clk_50m)
  );

  assign spien = 1;

  // FPGA initial reset logic
  // Provides an initial reset pulse for reset synchronisers even if
  // external reset is never asserted.
  initial fpga_rst_n_shreg = '0;

  always_ff @(posedge clk_cfg) begin
    fpga_rst_n_shreg <= {1'b1, fpga_rst_n_shreg[InitialResetCycles-1:1]};
  end

  assign fpga_rst_n_sync_cfg = fpga_rst_n_shreg[0];

  // External reset synchroniser
  // Synchronisation is required here because the external reset is used in logic here,
  // before it goes through the synchronisers in rstmgr.
  // Use asynchronous assertion with synchronous deassertion.
  prim_flop_2sync #(
    .Width      (1),
    .ResetValue ('0)
  ) u_mig_rst_sync_cfg (
    .clk_i  (clk_cfg),
    .rst_ni (ext_rst_ni & ftdi_rst_ni & fpga_rst_n_sync_cfg),
    .d_i    (1'b1),
    .q_o    (mig_rst_n_sync_cfg)
  );

  prim_flop_2sync #(
    .Width      (1),
    .ResetValue ('0)
  ) u_rst_sync_50m (
    .clk_i  (clk_50m),
    .rst_ni (ext_rst_ni & ftdi_rst_ni & fpga_rst_n_sync_cfg),
    .d_i    (1'b1),
    .q_o    (rst_n_sync_50m)
  );

  prim_flop_2sync #(
    .Width      (1),
    .ResetValue ('0)
  ) u_mig_axi_rst_sync_200m (
    .clk_i  (clk_200m),
    .rst_ni (u_top_chip_system.rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .d_i    (1'b1),
    .q_o    (mig_axi_rst_n_sync_200m)
  );

  // CHERI Mocha top
  top_chip_system #(
    .SramInitFile(SramInitFile),
    .RomInitFile (RomInitFile)
  ) u_top_chip_system (
    // Clock and reset
    .clk_i    (clk_50m),
    .rst_ni   (rst_n_sync_50m),

    // GPIO
    .gpio_i    ({23'd0, gpio_i}),
    .gpio_o    (gpio_outputs),
    .gpio_en_o (gpio_en_outputs),

    // UART
    .uart_rx_i,
    .uart_tx_o,

    // I^2C
    .i2c_scl_i    (i2c_scl_input),
    .i2c_scl_o    (i2c_scl_output),
    .i2c_scl_en_o (i2c_scl_en_output),
    .i2c_sda_i    (i2c_sda_input),
    .i2c_sda_o    (i2c_sda_output),
    .i2c_sda_en_o (i2c_sda_en_output),

    // Mailbox
    .axi_mailbox_req_i   ('0),
    .axi_mailbox_resp_o  ( ),
    .mailbox_ext_irq_o   ( ),

    // SPI device
    .spi_device_sck_i     (spi_device_sck_i),
    .spi_device_csb_i     (spi_device_csb_i),
    .spi_device_sd_o      (qspi_device_sdo),
    .spi_device_sd_en_o   (qspi_device_sdo_en),
    .spi_device_sd_i      ({3'h0, spi_device_sd_i}), // SPI MOSI = QSPI DQ0
    .spi_device_tpm_csb_i ('0),

    // SPI host
    .spi_host_sck_o    ( ),
    .spi_host_sck_en_o ( ),
    .spi_host_csb_o    ( ),
    .spi_host_csb_en_o ( ),
    .spi_host_sd_o     (spi_host_sd),
    .spi_host_sd_en_o  (spi_host_sd_en),
    // Mapping output 0 to input 1 because legacy SPI does not allow
    // bi-directional wires.
    // This only works in standard mode where sd_o[0]=COPI and
    // sd_i[1]=CIPO.
    .spi_host_sd_i     ({2'b0, spi_host_sd_en[0] ? spi_host_sd[0] : 1'b0, 1'b0}),

    // DRAM
    .dram_req_o  (dram_req),
    .dram_resp_i (dram_resp)
  );

  // GPIO tri-state output drivers
  // Instantiate for only the outputs connected to an FPGA pin
  for (genvar ii = 0; ii < 8; ii++) begin : gen_gpio_o
    OBUFT obuft (
      .I(gpio_outputs[ii]),
      .T(~gpio_en_outputs[ii]),
      .O(gpio_o[ii])
    );
  end

  // I^2C bi-directional buffers
  IOBUF i2c_scl_iobuf (
    .I (i2c_scl_output),      // system output / buffer internal input
    .T (~i2c_scl_en_output),  // system output enable / buffer tri-state enable
    .IO(i2c_scl_io),          // external FPGA pin / buffer external connection
    .O (i2c_scl_input)        // system input / buffer internal output
  );
  IOBUF i2c_sda_iobuf (
    .I (i2c_sda_output),
    .T (~i2c_sda_en_output),
    .IO(i2c_sda_io),
    .O (i2c_sda_input)
  );

  // SPI tri-state output driver
  OBUFT spi_obuft (
    .I(qspi_device_sdo[1]),     // SPI MISO = QSPI DQ1
    .T(~qspi_device_sdo_en[1]), // SPI MISO = QSPI DQ1
    .O(spi_device_sd_o)
  );

  // Async AXI FIFO from tag controller to MIG
  axi_cdc #(
    .aw_chan_t  (top_pkg::axi_dram_aw_chan_t),
    .w_chan_t   (top_pkg::axi_w_chan_t),
    .b_chan_t   (top_pkg::axi_dram_b_chan_t),
    .ar_chan_t  (top_pkg::axi_dram_ar_chan_t),
    .r_chan_t   (top_pkg::axi_dram_r_chan_t),
    .axi_req_t  (top_pkg::axi_dram_req_t),
    .axi_resp_t (top_pkg::axi_dram_resp_t),
    .LogDepth   (3),
    .SyncStages (2)   // Needs to be 2 for prim_flop_2sync
  ) u_mig_async_axi_fifo (
    .src_clk_i  (u_top_chip_system.clkmgr_clocks.clk_main_infra),
    .src_rst_ni (u_top_chip_system.rstmgr_resets.rst_main_n[rstmgr_pkg::Domain0Sel]),
    .src_req_i  (dram_req),
    .src_resp_o (dram_resp),
    .dst_clk_i  (clk_200m),
    .dst_rst_ni (mig_axi_rst_n_sync_200m),
    .dst_req_o  (mig_req),
    .dst_resp_i (mig_resp)
  );

  // DDR3 MIG
  // Part of the MIG (e.g. PHY) is not reset by mocha internal reset signals.
  // Therefore CVA6 may receive stray AXI responses after coming out of reset.
  // This is currently not handled.
  // TODO: Add handling of in-flight AXI requests when infrastructure is reset
  u_xlnx_mig_7_ddr3 u_ddr3_mig (
    // System clock input
    .sys_clk_p (sysclk_200m_pi),
    .sys_clk_n (sysclk_200m_ni),

    // System reset input
    // Asynchronous, at least 5ns
    .sys_rst (mig_rst_n_sync_cfg),

    // AXI interface reset input
    // Synchronous to ui_clk
    .aresetn (mig_axi_rst_n_sync_200m),

    // User interface clock and reset output
    .ui_clk          (clk_200m),
    .ui_clk_sync_rst ( ),

    // User interface signals
    .mmcm_locked         ( ),
    .init_calib_complete ( ),
    .device_temp         ( ),
    .app_sr_req          ('0),
    .app_ref_req         ('0),
    .app_zq_req          ('0),
    .app_sr_active       ( ),
    .app_ref_ack         ( ),
    .app_zq_ack          ( ),

    // DDR3 interface
    .ddr3_dq      (ddr3_dq),
    .ddr3_dqs_n   (ddr3_dqs_n),
    .ddr3_dqs_p   (ddr3_dqs_p),
    .ddr3_addr    (ddr3_addr),
    .ddr3_ba      (ddr3_ba),
    .ddr3_ras_n   (ddr3_ras_n),
    .ddr3_cas_n   (ddr3_cas_n),
    .ddr3_we_n    (ddr3_we_n),
    .ddr3_reset_n (ddr3_reset_n),
    .ddr3_ck_p    (ddr3_ck_p),
    .ddr3_ck_n    (ddr3_ck_n),
    .ddr3_cke     (ddr3_cke),
    .ddr3_cs_n    (ddr3_cs_n),
    .ddr3_dm      (ddr3_dm),
    .ddr3_odt     (ddr3_odt),

    // AXI interface
    // AXI write address channel
    .s_axi_awid    (mig_req.aw.id),
    .s_axi_awaddr  (mig_req.aw.addr[29:0]), // Implicit XOR with 0x8000_0000 for address translation
    .s_axi_awlen   (mig_req.aw.len),
    .s_axi_awsize  (mig_req.aw.size),
    .s_axi_awburst (mig_req.aw.burst),
    .s_axi_awlock  (mig_req.aw.lock),
    .s_axi_awcache (mig_req.aw.cache),
    .s_axi_awprot  (mig_req.aw.prot),
    .s_axi_awqos   (mig_req.aw.qos),
    .s_axi_awvalid (mig_req.aw_valid),
    .s_axi_awready (mig_resp.aw_ready),
    // mig_req.aw.region is unused
    // mig_req.aw.atop is unused
    // mig_req.aw.user is unused

    // AXI write data channel
    .s_axi_wdata  (mig_req.w.data),
    .s_axi_wstrb  (mig_req.w.strb),
    .s_axi_wlast  (mig_req.w.last),
    .s_axi_wvalid (mig_req.w_valid),
    .s_axi_wready (mig_resp.w_ready),

    // AXI write response channel
    .s_axi_bready (mig_req.b_ready),
    .s_axi_bid    (mig_resp.b.id),
    .s_axi_bresp  (mig_resp.b.resp),
    .s_axi_bvalid (mig_resp.b_valid),

    // AXI read address channel
    .s_axi_arid    (mig_req.ar.id),
    .s_axi_araddr  (mig_req.ar.addr[29:0]), // Implicit XOR with 0x8000_0000 for address translation
    .s_axi_arlen   (mig_req.ar.len),
    .s_axi_arsize  (mig_req.ar.size),
    .s_axi_arburst (mig_req.ar.burst),
    .s_axi_arlock  (mig_req.ar.lock),
    .s_axi_arcache (mig_req.ar.cache),
    .s_axi_arprot  (mig_req.ar.prot),
    .s_axi_arqos   (mig_req.ar.qos),
    .s_axi_arvalid (mig_req.ar_valid),
    .s_axi_arready (mig_resp.ar_ready),

    // AXI read data channel
    .s_axi_rready (mig_req.r_ready),
    .s_axi_rid    (mig_resp.r.id),
    .s_axi_rdata  (mig_resp.r.data),
    .s_axi_rresp  (mig_resp.r.resp),
    .s_axi_rlast  (mig_resp.r.last),
    .s_axi_rvalid (mig_resp.r_valid)
  );

  // AXI response fields not provided by the MIG are tied to 0
  assign mig_resp.b.user = '0;
  assign mig_resp.r.user = '0;

endmodule
