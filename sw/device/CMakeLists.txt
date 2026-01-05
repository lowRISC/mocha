# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

set(OBJDUMP_FLAGS --disassemble --demangle --source --file-headers --section-headers)

macro(add_exe_artefacts NAME)
    add_custom_command(
        TARGET ${NAME} POST_BUILD
        COMMAND ${CMAKE_OBJDUMP} ${OBJDUMP_FLAGS} "$<TARGET_FILE:${NAME}>" > "$<TARGET_FILE:${NAME}>.dump"
        COMMAND ${CMAKE_OBJCOPY} -O binary "$<TARGET_FILE:${NAME}>" "$<TARGET_FILE:${NAME}>.bin"
        COMMAND srec_cat "$<TARGET_FILE:${NAME}>.bin" -binary -byte-swap 8 -o "$<TARGET_FILE:${NAME}>.vmem" -vmem 64
        VERBATIM
    )
endmacro()

add_subdirectory(lib)
add_subdirectory(tests)
add_subdirectory(examples/hello_world)
add_subdirectory(examples/tag_check)
