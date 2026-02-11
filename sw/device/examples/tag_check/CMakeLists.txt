# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME tag_check)
add_executable(${NAME} tag_check.S)
target_link_libraries(${NAME} init_vectors_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS}" "-L${LDS_DIR}")
install(TARGETS ${NAME})
mocha_add_executable_artefacts(${NAME})
