# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME opensbi_test_payload)
add_executable(${NAME} test_payload.S)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--Ttext=0x80200000")
mocha_add_executable_artefacts(${NAME})
