// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

/* Register offsets (in bytes) for the LowRISC Core */
#define ETHERNET_MACLO_REG    (0x0800) /* MAC address low 32-bits */
#define ETHERNET_MACHI_REG    (0x0808) /* MAC address high 16-bits and MAC ctrl */
#define ETHERNET_TPLR_REG     (0x0810) /* Tx packet length */
#define ETHERNET_TFCS_REG     (0x0818) /* Tx frame check sequence register */
#define ETHERNET_MDIOCTRL_REG (0x0820) /* MDIO Control Register */
#define ETHERNET_RFCS_REG     (0x0828) /* Rx frame check sequence register(read) and last register(write) */
#define ETHERNET_RSR_REG      (0x0830) /* Rx status and reset register */
#define ETHERNET_RBAD_REG     (0x0838) /* Rx bad frame and bad fcs register arrays */
#define ETHERNET_RPLR_REG     (0x0840) /* Rx packet length register array */

// Buffer constants
#define ETHERNET_TXBUFF_OFFSET   (0x1000)         /* Transmit Buffer */
#define ETHERNET_RXBUFF_OFFSET   (0x4000)         /* Receive Buffer */
#define ETHERNET_RXBUFF_COUNT    (8)
#define ETHERNET_BUFF_SIZE_BYTES (0x800)

/* MAC Ctrl Register (MACHI) Bit Masks */
#define ETHERNET_MACHI_MACADDR_MASK  (0x0000FFFF) /* MAC high 16-bits mask */
#define ETHERNET_MACHI_COOKED_MASK   (0x00010000) /* obsolete flag */
#define ETHERNET_MACHI_LOOPBACK_MASK (0x00020000) /* Rx loopback packets */
#define ETHERNET_MACHI_ALLPKTS_MASK  (0x00400000) /* Rx all packets (promiscuous mode) */
#define ETHERNET_MACHI_IRQ_EN        (0x00800000) /* Rx packet interrupt enable */

/* MDIO Control Register Bit Masks */
#define ETHERNET_MDIOCTRL_MDIOCLK_MASK 0x00000001 /* MDIO Clock Mask */
#define ETHERNET_MDIOCTRL_MDIOOUT_MASK 0x00000002 /* MDIO Output Mask */
#define ETHERNET_MDIOCTRL_MDIOOEN_MASK 0x00000004 /* MDIO Output Enable Mask, 3-state enable, high=input, low=output */
#define ETHERNET_MDIOCTRL_MDIORST_MASK 0x00000008 /* MDIO Input Mask */
#define ETHERNET_MDIOCTRL_MDIOIN_MASK  0x00000008 /* MDIO Input Mask */

/* Transmit Status Register (TPLR) Bit Masks */
#define ETHERNET_TPLR_FRAME_ADDR_MASK  0x0FFF0000 /* Tx frame address */
#define ETHERNET_TPLR_PACKET_LEN_MASK  0x00000FFF /* Tx packet length */
#define ETHERNET_TPLR_BUSY_MASK        0x80000000 /* Tx busy mask */

/* Receive Status Register (RSR) */
#define ETHERNET_RSR_RECV_FIRST_MASK 0x0000000F   /* first available buffer (static) */
#define ETHERNET_RSR_RECV_NEXT_MASK  0x000000F0   /* current rx buffer (volatile) */
#define ETHERNET_RSR_RECV_LAST_MASK  0x00000F00   /* last available rx buffer (static) */
#define ETHERNET_RSR_RECV_DONE_MASK  0x00001000   /* Rx complete */
#define ETHERNET_RSR_RECV_IRQ_MASK   0x00002000   /* Rx irq bit */

/* General Ethernet Definitions */
#define ETHERNET_HEADER_OFFSET           12       /* Offset to length field */
#define ETHERNET_HEADER_SHIFT            16       /* Shift value for length */
#define ETHERNET_ARP_PACKET_SIZE         28       /* Max ARP packet size */
#define ETHERNET_HEADER_IP_LENGTH_OFFSET 16       /* IP Length Offset */

// From if_ether.h:
/*
 *  IEEE 802.3 Ethernet magic constants.  The frame sizes omit the preamble
 *  and FCS/CRC (frame check sequence).
 */
#define ETH_ALEN      6    /* Octets in one ethernet addr   */
#define ETH_TLEN      2    /* Octets in ethernet type field */
#define ETH_HLEN      14   /* Total octets in header.       */
#define ETH_ZLEN      60   /* Min. octets in frame sans FCS */
#define ETH_DATA_LEN  1500 /* Max. octets in payload        */
#define ETH_FRAME_LEN 1514 /* Max. octets in frame sans FCS */
#define ETH_FCS_LEN   4    /* Octets in the FCS             */

typedef void *ethernet_t;

static inline uint16_t htons(uint16_t x) {
    return (x >> 8) | (x << 8);
}
static inline uint32_t htonl(uint32_t x) {
    return htons(x >> 16) | (htons((uint16_t) x) << 16);
}
#define ntohs htons
#define ntohl htonl

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

static inline void ethernet_tx_buffer_write64(ethernet_t ethernet, uint32_t word_offset, uint64_t data) {
    if (((word_offset + 1) * sizeof(uint64_t)) > ETHERNET_BUFF_SIZE_BYTES) {
        return;
    }
    DEV_WRITE64(ethernet + ETHERNET_TXBUFF_OFFSET + word_offset * sizeof(uint64_t), data);
}

static inline uint64_t ethernet_tx_buffer_read64(ethernet_t ethernet, uint32_t word_offset) {
    if (((word_offset + 1) * sizeof(uint64_t)) > ETHERNET_BUFF_SIZE_BYTES) {
        return 0;
    }
    return DEV_READ64(ethernet + ETHERNET_TXBUFF_OFFSET + word_offset * sizeof(uint64_t));
}

static inline uint64_t ethernet_rx_buffer_read64(ethernet_t ethernet, uint8_t buf, uint32_t word_offset) {
    if (buf >= ETHERNET_RXBUFF_COUNT || ((word_offset + 1) * sizeof(uint64_t)) > ETHERNET_BUFF_SIZE_BYTES) {
        return 0;
    }
    return DEV_READ64(ethernet + ETHERNET_RXBUFF_OFFSET + buf * ETHERNET_BUFF_SIZE_BYTES + word_offset * sizeof(uint64_t));
}
