// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_chip_verilator (input logic clk_i, rst_ni);
  logic uart_rx;
  logic uart_tx;

  // CHERI Mocha top
  top_chip_system #(
  ) u_top_chip_system (
    .clk_i,
    .rst_ni,

    .uart_rx_i (uart_rx),
    .uart_tx_o (uart_tx)
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

endmodule
