# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME hello_world)
add_executable(${NAME} hello_world.c)
target_link_libraries(${NAME} hal_cheri startup_cheri runtime_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--defsym,BOOT_ROM_OFFSET=0x4000" "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})

set(NAME hello_world_verilator)
add_executable(${NAME} hello_world.c)
target_link_libraries(${NAME} hal_cheri startup_cheri runtime_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})

set(NAME spi)
add_executable(${NAME} spi.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--defsym,BOOT_ROM_OFFSET=0x4000" "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})

set(NAME i2c)
add_executable(${NAME} i2c.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--defsym,BOOT_ROM_OFFSET=0x4000" "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})

set(NAME software_reset)
add_executable(${NAME} software_reset.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--defsym,BOOT_ROM_OFFSET=0x4000" "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})

set(NAME tag_check)
add_executable(${NAME} tag_check.S)
target_link_libraries(${NAME} init_vectors_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--defsym,BOOT_ROM_OFFSET=0x4000" "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})

set(NAME tag_check_dram)
add_executable(${NAME} tag_check_dram.S)
target_link_libraries(${NAME} init_vectors_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-Wl,--defsym,BOOT_ROM_OFFSET=0x4000" "-T${LDS}" "-L${LDS_DIR}")
mocha_add_executable_artefacts(${NAME})
