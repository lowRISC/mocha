# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(SRCS mocha.c plic.c spi_device.c timer.c uart.c)

mocha_add_library(NAME hal LIBARIES SOURCES ${SRCS})
