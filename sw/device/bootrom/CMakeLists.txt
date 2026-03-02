# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME bootrom)
add_executable(${NAME} bootrom.c)
target_link_libraries(${NAME} hal_vanilla runtime_vanilla startup_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC 
  "-nodefaultlibs"
  "-Wl,--defsym,BOOT_ROM_OFFSET=0x00"
  "-T${LDS}"
  "-L${LDS_DIR}"
)
install(TARGETS ${NAME})
mocha_add_executable_artefacts(${NAME})
