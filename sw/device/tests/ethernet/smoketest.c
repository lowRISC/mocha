// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/mmio.h"
#include "hal/ethernet.h"
#include "hal/uart.h"
#include "runtime/print.h"
#include <stdbool.h>
#include <stdint.h>

bool reg_test(ethernet_t ethernet, uart_t uart)
{
    ethernet_rx_promiscuous_enable(ethernet);

    // MAC address write and read back
    uint64_t reg;
    ethernet_mac_address_set(ethernet, 0x55AA01EFCCDD);

    reg = ethernet_mac_address_get(ethernet);
    uprintf(uart, "eth mac: 0x%lx\n", reg);

    if (reg != 0x55AA01EFCCDD) {
        return false;
    }

    ethernet_rx_first_buffer_set(ethernet, 0);
    if (ethernet_rx_first_buffer_get(ethernet) != 0) {
        return false;
    }

    ethernet_rx_last_buffer_set(ethernet, ETHERNET_RXBUFF_COUNT - 1);
    if (ethernet_rx_last_buffer_get(ethernet) != ETHERNET_RXBUFF_COUNT - 1) {
        return false;
    }

    // Check if TX is busy
    if (ethernet_tx_is_busy(ethernet)) {
        uprintf(uart, "eth tx busy\n");
    } else {
        uprintf(uart, "eth tx not busy\n");
    }

    // write to tx buffer
    ethernet_tx_buffer_write64(ethernet, 0, 0xFFFFFFFFFFFFFFFFUL);
    ethernet_tx_buffer_write64(ethernet, 1, 0x5A5A5A5AA5A5A5A5UL);

    // Send packet
    ethernet_tx_packet_send(ethernet, 32);

    // Check if TX is busy
    if (ethernet_tx_is_busy(ethernet)) {
        uprintf(uart, "eth tx busy\n");
    } else {
        uprintf(uart, "eth tx not busy\n");
    }

    // Full read
    // Mapped: [0x800-0x900), [0x1000-0x1800), [0x4000-0x8000)
    for (int i = 0x800; i < 0x900; i=i+8) {
        uprintf(uart, "eth[0x%x] = 0x%lx\n", i, DEV_READ64(ethernet + i));
    }
    for (int i = 0x1000; i < 0x1800; i=i+8) {
        uprintf(uart, "eth[0x%x] = 0x%lx\n", i, DEV_READ64(ethernet + i));
    }
    for (int i = 0x4000; i < 0x8000; i=i+8) {
        uprintf(uart, "eth[0x%x] = 0x%lx\n", i, DEV_READ64(ethernet + i));
    }

    // Receive 10 packets
    uint8_t firstbuf;
    uint16_t len;
    for (int i=0; i < 10; ++i) {
        // Wait until there is a received packet
        while (!ethernet_rx_packet_pending(ethernet)) {
        }

        // Get RX buffer id (4 bits)
        firstbuf = ethernet_rx_first_buffer_get(ethernet);
        // Get packet length
        len = ethernet_rx_buffer_packet_length_get(ethernet, firstbuf & 0b111);

        uprintf(uart, "eth rx packet: buf = 0x%x, len = 0x%x\n", (uint32_t)firstbuf, (uint32_t)len);

        // Display content
        uprintf(uart, "eth rx u64 0 = 0x%lx\n", ethernet_rx_buffer_read64(ethernet, firstbuf & 0b111, 0));
        uprintf(uart, "eth rx u64 1 = 0x%lx\n", ethernet_rx_buffer_read64(ethernet, firstbuf & 0b111, 1));
        uprintf(uart, "eth rx u64 2 = 0x%lx\n", ethernet_rx_buffer_read64(ethernet, firstbuf & 0b111, 2));
        uprintf(uart, "eth rx u64 3 = 0x%lx\n", ethernet_rx_buffer_read64(ethernet, firstbuf & 0b111, 3));

        // Increment first buffer ID (4 bits)
        firstbuf = (firstbuf + 1) % 16;
        ethernet_rx_first_buffer_set(ethernet, firstbuf);
    }

    return true;
}

bool test_main(uart_t console)
{
    ethernet_t ethernet = mocha_system_ethernet();
    ethernet_init(ethernet);

    return reg_test(ethernet, console);
}
