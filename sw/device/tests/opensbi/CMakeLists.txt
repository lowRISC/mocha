# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME opensbi_test_payload)
add_executable(${NAME} test_payload.S)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
# The link address 0x80200000 is the address that OpenSBI will
# load the payload into and jump to it. This specific choice
# of offset (0x200000 = 2 MiB) is so that the load address is
# aligned to the size of a second-layer page (2 MiB on RV64),
# so that S-mode software can map itself into virtual memory
# using just a few large pages. This is a requirement for Linux too,
# see https://docs.kernel.org/arch/riscv/boot.html#kernel-location.
target_link_options(${NAME} PUBLIC "-Wl,--Ttext=0x80200000")
mocha_add_executable_artefacts(${NAME})
