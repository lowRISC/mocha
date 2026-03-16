// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/mocha.h"
#include "hal/spi_host.h"
#include <stdbool.h>
#include <stdint.h>

bool test_main()
{
    uint32_t tx_data = 0xDEADC0DE;
    uint32_t rx_data;
    spi_host_t spi_host;

    spi_host = mocha_system_spi_host();
    spi_host_init(spi_host);
    spi_host_write(spi_host, tx_data);
    rx_data = spi_host_read(spi_host);
    return tx_data == rx_data;
}
