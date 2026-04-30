# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(SRCS print.c string.c sdcard.c)

set(LIBS hal)

mocha_add_library(NAME runtime SOURCES ${SRCS} LIBRARIES ${LIBS})
