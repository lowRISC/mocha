# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(SRCS clkmgr.c gpio.c i2c.c mailbox.c mocha.c plic.c rstmgr.c spi_device.c spi_host.c timer.c uart.c)

mocha_add_library(NAME hal LIBRARIES SOURCES ${SRCS})
