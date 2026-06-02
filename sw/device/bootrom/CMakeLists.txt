# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(NAME bootrom)
add_executable(${NAME} bootrom.c data_load.S ../devicetree/mocha.S)
target_link_libraries(${NAME} hal_vanilla runtime_vanilla startup_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC
  "-nodefaultlibs"
  "-T${CMAKE_CURRENT_SOURCE_DIR}/rom.ld"
  "-L${LDS_DIR}"
)

add_custom_command(
    TARGET ${NAME} POST_BUILD
    COMMAND ${CMAKE_OBJDUMP} ${OBJDUMP_FLAGS} "$<TARGET_FILE:${NAME}>"
            > "$<TARGET_FILE:${NAME}>.dump"

    COMMAND ${CMAKE_OBJCOPY} -O binary
      "$<TARGET_FILE:${NAME}>"
      "$<TARGET_FILE:${NAME}>.bin"

    COMMAND "${PROJECT_SOURCE_DIR}/../hw/vendor/lowrisc_ip/ip/rom_ctrl/util/scramble_image.py"
      "${PROJECT_SOURCE_DIR}/../hw/data/top.hjson"
      "${PROJECT_SOURCE_DIR}/../hw/data/secrets.testing.hjson"
      base-rom
      $<TARGET_FILE:${NAME}>
      $<TARGET_FILE:${NAME}>_scrambled.vmem
      /dev/null

    VERBATIM
)

install(TARGETS ${NAME})
install(FILES "$<TARGET_FILE:${NAME}>_scrambled.vmem" DESTINATION . COMPONENT ${NAME})
install(FILES "$<TARGET_FILE:${NAME}>.bin" DESTINATION . COMPONENT ${NAME})
