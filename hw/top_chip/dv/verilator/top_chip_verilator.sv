// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_chip_verilator (input logic clk_i, rst_ni);
  // UART signals
  logic uart_rx;
  logic uart_tx;

  // SPI signals
  logic       spi_device_sck;
  logic       spi_device_csb;
  logic [3:0] qspi_device_sdo;
  logic [3:0] qspi_device_sdo_en;
  logic       spi_device_sdi;

  // CHERI Mocha top
  top_chip_system #(
  ) u_top_chip_system (
    .clk_i,
    .rst_ni,

    .uart_rx_i (uart_rx),
    .uart_tx_o (uart_tx),

    .spi_device_sck_i     (spi_device_sck),
    .spi_device_csb_i     (spi_device_csb),
    .spi_device_sd_o      (qspi_device_sdo),
    .spi_device_sd_en_o   (qspi_device_sdo_en),
    .spi_device_sd_i      ({3'h0, spi_device_sdi}), // SPI MOSI = QSPI DQ0
    .spi_device_tpm_csb_i ('0)
  );

  // Virtual UART
  uartdpi #(
    .BAUD        ( 921_600                                                   ),
    .FREQ        ( 50_000_000                                                ),
    .EXIT_STRING ( "Safe to exit simulator.\xd8\xaf\xfb\xa0\xc7\xe1\xa9\xd7" )
  ) u_uartdpi (
    .clk_i,
    .rst_ni,
    .active(1'b1),
    .tx_o  (uart_rx),
    .rx_i  (uart_tx)
  );

  // Virtual SPI host
  spidpi u_spidpi (
    .clk_i,
    .rst_ni,
    .spi_device_sck_o   (spi_device_sck),
    .spi_device_csb_o   (spi_device_csb),
    .spi_device_sdi_o   (spi_device_sdi),
    .spi_device_sdo_i   (qspi_device_sdo[1]),   // SPI MISO = QSPI DQ1
    .spi_device_sdo_en_i(qspi_device_sdo_en[1]) // SPI MISO = QSPI DQ1
  );
endmodule
