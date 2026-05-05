// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

#define ETHERNET_MACLO_REG (0x800)

#define ETHERNET_MACHI_REG          (0x808)
#define ETHERNET_MACHI_MACADDR_MASK (0xFFFF)
#define ETHERNET_MACHI_ALLPKTS_MASK (0x400000)
#define ETHERNET_MACHI_IRQ_EN       (0x800000)

#define ETHERNET_TPLR_REG       (0x810)
#define ETHERNET_TPLR_BUSY_MASK (0x80000000)

#define ETHERNET_MDIOCTRL_REG          (0x820)
#define ETHERNET_MDIOCTRL_MDIOCLK_MASK (0x1)
#define ETHERNET_MDIOCTRL_MDIOOUT_MASK (0x2)
#define ETHERNET_MDIOCTRL_MDIOOEN_MASK (0x4)
#define ETHERNET_MDIOCTRL_MDIOIN_MASK  (0x8)

#define ETHERNET_RFCS_REG (0x828)

#define ETHERNET_RSR_REG              (0x830)
#define ETHERNET_RSR_FIRST_BUF_OFFSET (0)
#define ETHERNET_RSR_NEXT_BUF_OFFSET  (4)
#define ETHERNET_RSR_LAST_BUF_OFFSET  (8)
#define ETHERNET_RSR_RX_DONE_MASK     (0x1000)
#define ETHERNET_RSR_RX_IRQ_MASK      (0x2000)

#define ETHERNET_RPLR_REG (0x840)

#define ETHERNET_TXBUFF_OFFSET   (0x1000)
#define ETHERNET_RXBUFF_OFFSET   (0x4000)
#define ETHERNET_RXBUFF_COUNT    (8)
#define ETHERNET_BUFF_SIZE_BYTES (0x800)

#define ETHERNET_PACKET_LEN_MASK (0x7FF)
#define ETHERNET_BUF_MASK        (0xF)

typedef void *ethernet_t;

void ethernet_mac_address_set(ethernet_t ethernet, uint64_t address);
uint64_t ethernet_mac_address_get(ethernet_t ethernet);
void ethernet_rx_promiscuous_enable(ethernet_t ethernet);
void ethernet_rx_promiscuous_disable(ethernet_t ethernet);
bool ethernet_rx_promiscuous_get(ethernet_t ethernet);
bool ethernet_tx_is_busy(ethernet_t ethernet);
void ethernet_tx_packet_send(ethernet_t ethernet, uint16_t len_bytes);
void ethernet_rx_first_buffer_set(ethernet_t ethernet, uint8_t buf);
uint8_t ethernet_rx_first_buffer_get(ethernet_t ethernet);
uint8_t ethernet_rx_next_buffer_get(ethernet_t ethernet);
void ethernet_rx_last_buffer_set(ethernet_t ethernet, uint8_t buf);
uint8_t ethernet_rx_last_buffer_get(ethernet_t ethernet);
bool ethernet_rx_packet_pending(ethernet_t ethernet);
uint16_t ethernet_rx_buffer_packet_length_get(ethernet_t ethernet, uint8_t buf);
void ethernet_init(ethernet_t ethernet);

static inline void
ethernet_tx_buffer_write64(ethernet_t ethernet, uint32_t word_offset, uint64_t data)
{
    if (((word_offset + 1) * sizeof(uint64_t)) > ETHERNET_BUFF_SIZE_BYTES) {
        return;
    }
    DEV_WRITE64(ethernet + ETHERNET_TXBUFF_OFFSET + word_offset * sizeof(uint64_t), data);
}

static inline uint64_t ethernet_tx_buffer_read64(ethernet_t ethernet, uint32_t word_offset)
{
    if (((word_offset + 1) * sizeof(uint64_t)) > ETHERNET_BUFF_SIZE_BYTES) {
        return 0;
    }
    return DEV_READ64(ethernet + ETHERNET_TXBUFF_OFFSET + word_offset * sizeof(uint64_t));
}

static inline uint64_t
ethernet_rx_buffer_read64(ethernet_t ethernet, uint8_t buf, uint32_t word_offset)
{
    if (buf >= ETHERNET_RXBUFF_COUNT ||
        ((word_offset + 1) * sizeof(uint64_t)) > ETHERNET_BUFF_SIZE_BYTES) {
        return 0;
    }
    return DEV_READ64(ethernet + ETHERNET_RXBUFF_OFFSET + buf * ETHERNET_BUFF_SIZE_BYTES +
                      word_offset * sizeof(uint64_t));
}
