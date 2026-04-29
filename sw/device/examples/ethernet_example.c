// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "runtime/print.h"

int main(void)
{
    uart_t uart = mocha_system_uart();
    ethernet_t ethernet = mocha_system_ethernet();

    uprintf(uart, "Ethernet example\n");

    ethernet_init(ethernet);

    // Set MAC address to 9A:BC:12:34:56:78
    ethernet_mac_address_set(ethernet, 0x9ABC12345678);

    // Initialise Tx buffer
    for (int i = 0; i < 1600 / 8; ++i) {
        ethernet_tx_buffer_write64(ethernet, i,
                                   (i & 0b100) == 0 ? 0x5555555500000000UL : 0xAAAAAAAAFFFFFFFFUL);
    }

    uprintf(uart, "Sending packets\n");

    // Wait until Tx is not busy
    while (ethernet_tx_is_busy(ethernet)) {
    }

    for (int i = 0; i < 2; ++i) {
        // Write to Tx buffer
        ethernet_tx_buffer_write64(ethernet, 0, 0x1122334455667788UL);
        ethernet_tx_buffer_write64(ethernet, 1, 0x5A5A5A5AA5A5A5A5UL);

        // Send 64 byte packet
        ethernet_tx_packet_send(ethernet, 64);

        // Wait until Tx is not busy
        while (ethernet_tx_is_busy(ethernet)) {
        }

        // Write to Tx buffer
        ethernet_tx_buffer_write64(ethernet, 0, 0xFFEEDDCCBBAA9988UL);
        ethernet_tx_buffer_write64(ethernet, 1, 0x5A5A5A5AA5A5FFEEUL);

        for (int j = 0; j < 3; ++j) {
            // Send 1500 byte packet
            ethernet_tx_packet_send(ethernet, 1500);

            // Wait until Tx is not busy
            while (ethernet_tx_is_busy(ethernet)) {
            }
        }

        // Write to Tx buffer
        ethernet_tx_buffer_write64(ethernet, 0, 0x0102030450607080UL);
        ethernet_tx_buffer_write64(ethernet, 1, 0x5A5A5A5AA5A54455UL);

        // Send 100 byte packet
        ethernet_tx_packet_send(ethernet, 100);

        // Wait until Tx is not busy
        while (ethernet_tx_is_busy(ethernet)) {
        }
    }

    // Receive 100 packets
    uprintf(uart, "Receiving packets\n");
    uint8_t firstbuf;
    uint16_t len;
    uint16_t len_words;
    for (int i = 0; i < 100; ++i) {
        // Wait until there is a received packet
        while (!ethernet_rx_packet_pending(ethernet)) {
        }

        // Get Rx buffer id (4 bits)
        firstbuf = ethernet_rx_first_buffer_get(ethernet);
        // Increment first buffer ID (4 bits)
        firstbuf = (firstbuf + 1) & 0b1111;

        // Get packet length
        // This includes an additional 4 bytes for the FCS
        len = ethernet_rx_buffer_packet_length_get(ethernet, firstbuf & 0b111);
        len_words = len / sizeof(uint64_t);
        if ((len % sizeof(uint64_t)) != 0) {
            ++len_words;
        }

        uprintf(uart, "Received packet: buf = 0x%x (0x%x), len = 0x%x\n", (uint32_t)firstbuf,
                (uint32_t)(firstbuf & 0b111), (uint32_t)len);

        // Display packet content
        uprintf(uart, "hex content =");
        for (uint32_t i = 0; i < (uint32_t)len_words; ++i) {
            uprintf(uart, " %lx", ethernet_rx_buffer_read64(ethernet, firstbuf & 0b111, i));
        }
        uprintf(uart, "\n\n");

        // Update first buffer
        ethernet_rx_first_buffer_set(ethernet, firstbuf);
    }

    return 0;
}

void _trap_handler(struct trap_registers *registers, struct trap_context *context)
{
    (void)registers;
    (void)context;
}
