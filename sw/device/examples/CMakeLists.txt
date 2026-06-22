# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Custom target that represents all example binaries.
add_custom_target(examples)

# Function to add an example binary target to the
# set of examples. These can then be installed as
# part of the examples component.
function (mocha_add_example TARGET)
    add_dependencies(examples ${TARGET})
    add_custom_command(
        TARGET ${TARGET} POST_BUILD
        COMMAND ${CMAKE_OBJCOPY} -O binary "$<TARGET_FILE:${TARGET}>"
                "$<TARGET_FILE:${TARGET}>.bin"
        COMMAND srec_cat "$<TARGET_FILE:${TARGET}>.bin" -binary -byte-swap 8
                -o "$<TARGET_FILE:${TARGET}>.vmem" -vmem 64
        VERBATIM
    )

    install(TARGETS ${TARGET} DESTINATION . COMPONENT examples)
    install(FILES "$<TARGET_FILE:${TARGET}>.vmem" DESTINATION . COMPONENT examples)
    install(FILES "$<TARGET_FILE:${TARGET}>.bin" DESTINATION . COMPONENT examples)
endfunction()

set(NAME hello_world)
add_executable(${NAME} hello_world.c)
target_link_libraries(${NAME} hal_cheri startup_cheri runtime_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME infinite_loop)
add_executable(${NAME} infinite_loop.c)
target_link_libraries(${NAME} hal_cheri startup_cheri runtime_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME spi)
add_executable(${NAME} spi.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME i2c)
add_executable(${NAME} i2c.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME software_reset)
add_executable(${NAME} software_reset.c)
target_link_libraries(${NAME} hal_vanilla startup_vanilla runtime_vanilla)
target_compile_options(${NAME} PUBLIC ${VANILLA_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME tag_check)
add_executable(${NAME} tag_check.S)
target_link_libraries(${NAME} init_vectors_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME tag_check_dram)
add_executable(${NAME} tag_check_dram.S)
target_link_libraries(${NAME} init_vectors_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})

set(NAME ethernet_example)
add_executable(${NAME} ethernet_example.c)
target_link_libraries(${NAME} hal_cheri startup_cheri runtime_cheri)
target_compile_options(${NAME} PUBLIC ${CHERI_FLAGS})
target_link_options(${NAME} PUBLIC "-T${LDS_DIR}/mocha_sram.ld" "-L${LDS_DIR}")
mocha_add_example(${NAME})
