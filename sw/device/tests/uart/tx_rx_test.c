// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

#define TX_RX_MAX_BYTES (32u)

// The symbols below are overwritten through sw_symbol_backdoor_overwrite() in
// top_chip_dv_uart_tx_rx_vseq.sv, which also echoes every byte sent on uart_tx_o back onto
// uart_rx_i
volatile const uint8_t tx_rx_byte_count = TX_RX_MAX_BYTES;
volatile const uint8_t tx_rx_data[TX_RX_MAX_BYTES] = {
    0x00, 0xff, 0x55, 0xaa, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20,
    0x40, 0x80, 0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f,
};

bool test_main(uart_t console)
{
    // Turn both internal loopbacks off so the bytes can only come back through the chip pins
    uart_loopback_set(console, false, false);

    // The console UART is the one on the chip pins, so nothing else may be printed until every
    // echoed byte has been read back
    for (uint8_t idx = 0; idx < tx_rx_byte_count; idx++) {
        uart_out(console, (char)tx_rx_data[idx]);
    }

    for (uint8_t idx = 0; idx < tx_rx_byte_count; idx++) {
        uint8_t rx = (uint8_t)uart_in(console);
        if (rx != tx_rx_data[idx]) {
            uprintf(console, "Byte %x: expected %x, got %x\n", idx, tx_rx_data[idx], rx);
            return false;
        }
    }
    return true;
}
