// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#pragma once

#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

#define SPI_HOST_INTR_STATE_REG                  (0x0)
#define SPI_HOST_INTR_ENABLE_REG                 (0x4)
#define SPI_HOST_INTR_TEST_REG                   (0x8)
#define SPI_HOST_CONTROL_REG                     (0x10)
#define SPI_HOST_CONTROL_SPIEN_MASK              (1u << 31)
#define SPI_HOST_CONTROL_OUTPUTEN_MASK           (1u << 29)
#define SPI_HOST_STATUS_REG                      (0x14)
#define SPI_HOST_CONFIGOPTS_REG                  (0x18)
#define SPI_HOST_CSID_REG                        (0x1C)
#define SPI_HOST_COMMAND_REG                     (0x20)
#define SPI_HOST_COMMAND_DIRECTION_OFFSET        (3)
#define SPI_HOST_COMMAND_DIRECTION_RECEIVE       (1 << SPI_HOST_COMMAND_DIRECTION_OFFSET)
#define SPI_HOST_COMMAND_DIRECTION_TRANSMIT      (2 << SPI_HOST_COMMAND_DIRECTION_OFFSET)
#define SPI_HOST_COMMAND_DIRECTION_BIDIRECTIONAL (3 << SPI_HOST_COMMAND_DIRECTION_OFFSET)
#define SPI_HOST_COMMAND_LEN_OFF                 (5)
#define SPI_HOST_COMMAND_LEN_MASK                (0xFFFFF << SPI_HOST_COMMAND_LEN_OFF)
#define SPI_HOST_RXDATA_REG                      (0x24)
#define SPI_HOST_TXDATA_REG                      (0x28)

typedef void *spi_host_t;

void spi_host_init(spi_host_t spi_host);
void spi_host_write(spi_host_t spi_host, uint32_t data);
uint32_t spi_host_read(spi_host_t spi_host);
