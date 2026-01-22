# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(SRCS main.c)
set(LIBS hal startup)

mocha_add_library(NAME test_framework SOURCES ${SRCS} LIBRARIES ${LIBS})
