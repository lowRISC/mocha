# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME hello_world)
add_executable(${NAME} hello_world.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-T" "${LDS}" "-L" "${LDS_DIR}")
install(TARGETS ${NAME})
mocha_add_executable_artefacts(${NAME})
