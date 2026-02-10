# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME hello_world)
add_executable(${NAME} hello_world.c)
target_link_libraries(${NAME} hal startup runtime)
target_compile_options(${NAME} PUBLIC ${NON_CHERI_FLAGS})
install(TARGETS ${NAME})
mocha_add_executable_artefacts(${NAME})
