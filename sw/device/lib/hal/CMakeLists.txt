# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

add_library(hal OBJECT uart.c)
target_compile_options(hal PUBLIC ${NON_CHERI_FLAGS})
target_include_directories(hal PUBLIC "./..")
