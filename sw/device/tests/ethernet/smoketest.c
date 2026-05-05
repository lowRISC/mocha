// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mmio.h"
#include "hal/mocha.h"
#include "runtime/print.h"

bool reg_test(ethernet_t ethernet)
{
    ethernet_mac_address_set(ethernet, 0x55AA55AA55AA);
    if (ethernet_mac_address_get(ethernet) != 0x55AA55AA55AA) {
        return false;
    }

    ethernet_mac_address_set(ethernet, 0xAA55AA55AA55);
    if (ethernet_mac_address_get(ethernet) != 0xAA55AA55AA55) {
        return false;
    }

    ethernet_rx_promiscuous_disable(ethernet);
    if (ethernet_rx_promiscuous_get(ethernet)) {
        return false;
    }

    ethernet_rx_promiscuous_enable(ethernet);
    if (!ethernet_rx_promiscuous_get(ethernet)) {
        return false;
    }

    ethernet_rx_first_buffer_set(ethernet, 0x5);
    if (ethernet_rx_first_buffer_get(ethernet) != 0x5) {
        return false;
    }

    ethernet_rx_first_buffer_set(ethernet, 0xA);
    if (ethernet_rx_first_buffer_get(ethernet) != 0xA) {
        return false;
    }

    if (ethernet_rx_next_buffer_get(ethernet) >= 16) {
        return false;
    }

    ethernet_rx_last_buffer_set(ethernet, 0x5);
    if (ethernet_rx_last_buffer_get(ethernet) != 0x5) {
        return false;
    }

    ethernet_rx_last_buffer_set(ethernet, 0xA);
    if (ethernet_rx_last_buffer_get(ethernet) != 0xA) {
        return false;
    }

    return true;
}

bool tx_buf_test(ethernet_t ethernet)
{
    for (uint32_t i = 0; i < 10; ++i) {
        ethernet_tx_buffer_write64(ethernet, i, 0x3747F7781A13BDFBUL);
    }
    for (uint32_t i = 0; i < 10; ++i) {
        ethernet_tx_buffer_write64(ethernet, (ETHERNET_BUFF_SIZE_BYTES / sizeof(uint64_t)) - 1 - i,
                                   0x8D4B4FBDA7BC77DFUL);
    }

    for (int i = 0; i < 10; ++i) {
        if (ethernet_tx_buffer_read64(ethernet, i) != 0x3747F7781A13BDFBUL) {
            return false;
        }
    }
    for (int i = 0; i < 10; ++i) {
        if (ethernet_tx_buffer_read64(ethernet, (ETHERNET_BUFF_SIZE_BYTES / sizeof(uint64_t)) - 1 -
                                                    i) != 0x8D4B4FBDA7BC77DFUL) {
            return false;
        }
    }

    return true;
}

bool send_packet_test(ethernet_t ethernet)
{
    // Wait until Tx is not busy
    while (ethernet_tx_is_busy(ethernet)) {
    }

    // Send a large 1500 byte packet
    ethernet_tx_packet_send(ethernet, 1500);

    // Tx should now be busy
    if (!ethernet_tx_is_busy(ethernet)) {
        return false;
    }

    // Tx should eventually become not busy
    while (ethernet_tx_is_busy(ethernet)) {
    }

    return true;
}

bool test_main()
{
    ethernet_t ethernet = mocha_system_ethernet();
    ethernet_init(ethernet);

    return reg_test(ethernet) && tx_buf_test(ethernet) && send_packet_test(ethernet);
}
