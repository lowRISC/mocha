# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(SRCS mocha.c gpio.c plic.c spi_device.c timer.c uart.c clkmgr.c)

mocha_add_library(NAME hal LIBRARIES SOURCES ${SRCS})
