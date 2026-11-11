// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// The UVM testbench answers the SPI host with an SPI device agent, which plays each 4-byte word it
// receives back during the next word of the same transaction.

#include "hal/mmio.h"
#include "hal/mocha.h"
#include "hal/spi_host.h"
#include <stdbool.h>
#include <stdint.h>

// SCK at a quarter of the SPI host clock (CLKDIV 1), and one SCK cycle each of chip select lead,
// trail and idle time. The other fields keep their reset value, SPI mode 0.
enum {
    spi_host_configopts = (1u << 24) | (1u << 20) | (1u << 16) | 1u,
};

// Queue a one-word segment, keeping the chip select asserted afterwards if csaat is set
static void spi_host_word_segment(spi_host_t spi_host, uint32_t direction, bool csaat)
{
    while (!(spi_host_status(spi_host) & SPI_HOST_STATUS_READY_MASK)) {
    }
    DEV_WRITE(spi_host + SPI_HOST_COMMAND_REG,
              direction | ((uint32_t)csaat << SPI_HOST_COMMAND_CSAAT_OFFSET) |
                  (((sizeof(uint32_t) - 1) << SPI_HOST_COMMAND_LEN_OFF) &
                   SPI_HOST_COMMAND_LEN_MASK));
}

static uint32_t spi_host_read_word(spi_host_t spi_host)
{
    while (spi_host_status(spi_host) & SPI_HOST_STATUS_RXEMPTY_MASK) {
    }
    return spi_host_read(spi_host);
}

bool test_main()
{
    const uint32_t tx_data[2] = { 0xDEADC0DEu, 0x21523F21u };
    uint32_t rx_data[2];
    spi_host_t spi_host = mocha_system_spi_host();

    DEV_WRITE(spi_host + SPI_HOST_CONFIGOPTS_REG, spi_host_configopts);
    DEV_WRITE(spi_host + SPI_HOST_CSID_REG, 0);
    spi_host_init(spi_host);
    if (DEV_READ(spi_host + SPI_HOST_CONFIGOPTS_REG) != spi_host_configopts) {
        return false;
    }

    // In one transaction, send the first word, then send the second while receiving the first back,
    // then receive the second
    DEV_WRITE(spi_host + SPI_HOST_TXDATA_REG, tx_data[0]);
    DEV_WRITE(spi_host + SPI_HOST_TXDATA_REG, tx_data[1]);
    spi_host_word_segment(spi_host, SPI_HOST_COMMAND_DIRECTION_TRANSMIT, true);
    spi_host_word_segment(spi_host, SPI_HOST_COMMAND_DIRECTION_BIDIRECTIONAL, true);
    spi_host_word_segment(spi_host, SPI_HOST_COMMAND_DIRECTION_RECEIVE, false);

    rx_data[0] = spi_host_read_word(spi_host);
    rx_data[1] = spi_host_read_word(spi_host);

    return rx_data[0] == tx_data[0] && rx_data[1] == tx_data[1];
}
