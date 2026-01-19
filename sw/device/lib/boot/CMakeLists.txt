# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(SRCS boot.S init_vectors.S)

mocha_add_library(NAME startup SOURCES ${SRCS} LIBRARIES)
mocha_add_library(NAME init_vectors SOURCES init_vectors.S LIBRARIES)
