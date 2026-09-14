// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/autogen/ethernet.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

// Depth in 64-bit words
#define ETHERNET_RX_BUF_DEPTH   1024
#define ETHERNET_RX_TABLE_DEPTH 8
#define ETHERNET_TX_BUF_DEPTH   256

// entries in the RXTABLE have the following format:
#define ETHERNET_RXTABLE_PKT_LEN_MASK   (0x00000000FFFF0000) // bits 31:16 are the packet length in bytes
#define ETHERNET_RXTABLE_PKT_PTR_MASK   (0xFFFFFFFF00000000) // upper 32 bits are the packet pointer
#define ETHERNET_RXTABLE_REASON_MASK    (0x3) // bits 1:0 indicate the reason the packet was captured (see ethernet_capture_reason_e)

#define ETHERNET_RXTABLE_PKT_LEN_OFFSET (16)
#define ETHERNET_RXTABLE_PKT_PTR_OFFSET (32)
#define ETHERNET_RXTABLE_REASON_OFFSET  (0)


typedef enum {
    MAC_MATCHES     = 0,
    MAC_BROADCAST   = 1,
    MAC_MULTICAST   = 2,
    NON_MAC_MATCH   = 3
} ethernet_capture_reason_e;

typedef struct [[gnu::aligned(4)]] {
    ethernet_capture_reason_e reason : 2;
    uint32_t : 14; // reserved
    uint16_t pkt_len : 16;
    uint32_t pkt_ptr : 32;
} ethernet_pkt_metadata_t;

// Low-level methods
ethernet_intr ethernet_intr_state_get(ethernet_t ethernet);
ethernet_intr ethernet_intr_mask_get(ethernet_t ethernet);
void ethernet_intr_mask_set(ethernet_t ethernet, ethernet_intr intr_mask);
void ethernet_test_intr_fire(ethernet_t ethernet);
void ethernet_test_intr_clear(ethernet_t ethernet);
void ethernet_tx_done_intr_clear(ethernet_t ethernet);
void ethernet_packet_lost_intr_clear(ethernet_t ethernet);
ethernet_status ethernet_status_get(ethernet_t ethernet);
void ethernet_mode_set(ethernet_t ethernet, bool promiscuous_en, bool loopback_en);
ethernet_ctrl ethernet_mode_get(ethernet_t ethernet);
uint64_t ethernet_mac_address_get(ethernet_t ethernet);
void ethernet_mac_address_set(ethernet_t ethernet, uint64_t address);
void ethernet_tx_buffer_write64(ethernet_t ethernet, uint32_t word_offset, uint64_t data);
uint64_t ethernet_rx_buffer_read64(ethernet_t ethernet, uint32_t word_offset);
uint8_t ethernet_rx_buffer_read_byte(ethernet_t ethernet, uint16_t byte_offset);
ethernet_pkt_metadata_t ethernet_rx_buffer_metadata_get(ethernet_t ethernet, uint8_t index);
void ethernet_read_packet_data_raw(ethernet_t ethernet, uint16_t packet_start_ptr, uint16_t len, uint8_t *data);
uint8_t ethernet_tx_packet_trigger(ethernet_t ethernet, uint16_t len_bytes);
void ethernet_rx_pop_packet(ethernet_t ethernet);
bool ethernet_tx_is_busy(ethernet_t ethernet);
bool ethernet_rx_packet_pending(ethernet_t ethernet);
ethernet_mdio_ctrl ethernet_mdio_ctrl_raw_get(ethernet_t ethernet);
void ethernet_mdio_ctrl_raw_set(ethernet_t ethernet, ethernet_mdio_ctrl mdio_ctrl);

/// MDIO bit banging interface
void ethernet_mdio_dir_set(ethernet_t ethernet, bool mdio_out_en);
void ethernet_mdio_out_set(ethernet_t ethernet, bool mdio_out);
bool ethernet_mdio_in_get(ethernet_t ethernet);
void ethernet_mdio_c_set(ethernet_t ethernet, bool mdio_clk);

void ethernet_mdc_pulse(ethernet_t ethernet);
void ethernet_mdio_write_bit(ethernet_t ethernet, bool bit);
bool ethernet_mdio_read_bit(ethernet_t ethernet);

// High-level interface
void ethernet_init(ethernet_t ethernet, uint64_t mac_address, bool promiscuous, ethernet_intr intr_mask);
ethernet_pkt_metadata_t ethernet_read_and_pop_oldest_packet(ethernet_t ethernet, uint8_t *data);
uint8_t ethernet_send_packet(ethernet_t ethernet, const uint8_t *data, uint16_t len_bytes);
void ethernet_disable(ethernet_t ethernet);

void ethernet_mdio_write(ethernet_t ethernet, uint8_t phy_addr, uint8_t reg_addr, uint16_t data);
uint16_t ethernet_mdio_read(ethernet_t ethernet, uint8_t phy_addr, uint8_t reg_addr);
