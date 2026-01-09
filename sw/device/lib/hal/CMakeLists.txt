# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

add_library(hal OBJECT mocha.c uart.c timer.c)
add_library(hal_cheri OBJECT mocha.c uart.c timer.c)
target_compile_options(hal PUBLIC ${NON_CHERI_FLAGS})
target_compile_options(hal_cheri PUBLIC ${CHERI_FLAGS})
target_include_directories(hal PUBLIC "./..")
target_include_directories(hal_cheri PUBLIC "./..")
