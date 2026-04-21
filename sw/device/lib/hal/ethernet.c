// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/ethernet.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

void ethernet_mac_address_set(ethernet_t ethernet, uint64_t address)
{
    DEV_WRITE64(ethernet + ETHERNET_MACLO_REG, (uint32_t)(address >> 16));
    uint64_t reg = DEV_READ64(ethernet + ETHERNET_MACHI_REG);
    reg = reg & ~ETHERNET_MACHI_MACADDR_MASK;
    DEV_WRITE64(ethernet + ETHERNET_MACHI_REG,
                reg | (uint16_t)(address & ETHERNET_MACHI_MACADDR_MASK));
}

uint64_t ethernet_mac_address_get(ethernet_t ethernet)
{
    uint16_t hi = DEV_READ64(ethernet + ETHERNET_MACHI_REG) & ETHERNET_MACHI_MACADDR_MASK;
    uint32_t lo = DEV_READ64(ethernet + ETHERNET_MACLO_REG);
    return ((uint64_t)hi) | ((uint64_t)lo << 16);
}

void ethernet_rx_promiscuous_enable(ethernet_t ethernet)
{
    DEV_WRITE64(ethernet + ETHERNET_MACHI_REG,
                DEV_READ64(ethernet + ETHERNET_MACHI_REG) | ETHERNET_MACHI_ALLPKTS_MASK);
}

void ethernet_rx_promiscuous_disable(ethernet_t ethernet)
{
    DEV_WRITE64(ethernet + ETHERNET_MACHI_REG,
                DEV_READ64(ethernet + ETHERNET_MACHI_REG) & ~ETHERNET_MACHI_ALLPKTS_MASK);
}

bool ethernet_rx_promiscuous_get(ethernet_t ethernet)
{
    return (DEV_READ64(ethernet + ETHERNET_MACHI_REG) & ETHERNET_MACHI_ALLPKTS_MASK) != 0;
}

bool ethernet_tx_is_busy(ethernet_t ethernet)
{
    return (DEV_READ64(ethernet + ETHERNET_TPLR_REG) & ETHERNET_TPLR_BUSY_MASK) != 0;
}

void ethernet_tx_packet_send(ethernet_t ethernet, uint16_t len_bytes)
{
    DEV_WRITE64(ethernet + ETHERNET_TPLR_REG, (uint64_t)len_bytes);
}

void ethernet_rx_first_buffer_set(ethernet_t ethernet, uint8_t buf)
{
    DEV_WRITE64(ethernet + ETHERNET_RSR_REG, (uint64_t)buf);
}

uint8_t ethernet_rx_first_buffer_get(ethernet_t ethernet)
{
    return (uint8_t)(DEV_READ64(ethernet + ETHERNET_RSR_REG) & 0xF);
}

uint8_t ethernet_rx_next_buffer_get(ethernet_t ethernet)
{
    return (uint8_t)((DEV_READ64(ethernet + ETHERNET_RSR_REG) >> 4) & 0xF);
}

void ethernet_rx_last_buffer_set(ethernet_t ethernet, uint8_t buf)
{
    DEV_WRITE64(ethernet + ETHERNET_RFCS_REG, (uint64_t)buf);
}

uint8_t ethernet_rx_last_buffer_get(ethernet_t ethernet)
{
    return (uint8_t)((DEV_READ64(ethernet + ETHERNET_RSR_REG) >> 8) & 0xF);
}

bool ethernet_rx_packet_pending(ethernet_t ethernet)
{
    return (DEV_READ64(ethernet + ETHERNET_RSR_REG) & ETHERNET_RSR_RECV_DONE_MASK) != 0;
}

uint16_t ethernet_rx_buffer_packet_length_get(ethernet_t ethernet, uint8_t buf)
{
    if (buf >= ETHERNET_RXBUFF_COUNT) {
        return (uint16_t)(-1);
    }
    return DEV_READ64(ethernet + ETHERNET_RPLR_REG + (buf << 3)) & 0x7FF;
}

void ethernet_init(ethernet_t ethernet)
{
    ethernet_rx_first_buffer_set(ethernet, 0);
    ethernet_rx_last_buffer_set(ethernet, ETHERNET_RXBUFF_COUNT - 1);
}
