# Copyright lowRISC contributors (COSMIC project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

add_library(startup OBJECT boot.S init_vectors.S)
target_compile_options(startup PUBLIC ${NON_CHERI_FLAGS})

add_library(init_vectors OBJECT init_vectors.S)
target_compile_options(init_vectors PUBLIC ${NON_CHERI_FLAGS})

add_library(init_vectors_cheri OBJECT init_vectors.S)
target_compile_options(init_vectors_cheri PUBLIC ${CHERI_FLAGS})

