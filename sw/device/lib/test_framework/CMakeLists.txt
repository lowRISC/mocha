# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

add_library(test_framework OBJECT main.c)
target_compile_options(test_framework PUBLIC ${NON_CHERI_FLAGS})
target_link_libraries(test_framework PUBLIC hal startup)

add_library(test_framework_cheri OBJECT main.c)
target_compile_options(test_framework_cheri PUBLIC ${CHERI_FLAGS})
target_link_libraries(test_framework_cheri PUBLIC hal_cheri startup_cheri)
