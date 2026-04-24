// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/spi_host.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

void spi_host_init(spi_host_t spi_host)
{
    DEV_WRITE(spi_host + SPI_HOST_CONTROL_REG,
              SPI_HOST_CONTROL_SPIEN_MASK | SPI_HOST_CONTROL_OUTPUTEN_MASK);
}

void spi_host_write(spi_host_t spi_host, uint32_t data)
{
    DEV_WRITE(spi_host + SPI_HOST_TXDATA_REG, data);
    DEV_WRITE(spi_host + SPI_HOST_COMMAND_REG,
              SPI_HOST_COMMAND_DIRECTION_BIDIRECTIONAL |
                  ((3 << SPI_HOST_COMMAND_LEN_OFF) & SPI_HOST_COMMAND_LEN_MASK));
}

uint32_t spi_host_read(spi_host_t spi_host)
{
    return DEV_READ(spi_host + SPI_HOST_RXDATA_REG);
}
